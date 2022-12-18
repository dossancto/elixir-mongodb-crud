defmodule RestApi.Router do
  alias RestApi.JsonUtils, as: JSON

  use Plug.Router

  plug(Plug.Logger)

  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)
  # Handler for GET request with "/" path
  get "/" do
    send_resp(conn, 200, "OK")
  end

  get "/knock" do
    case Mongo.command(:mongo, ping: 1) do
      {:ok, _res} -> send_resp(conn, 200, "Who is there")
      {:error, _err} -> send_resp(conn, 500, "Something went wrong")
    end
  end

  get "/posts" do
    # Find all the posts in the database
    posts =
      Mongo.find(:mongo, "Posts", %{})
      # For each of the post normalise the id
      |> Enum.map(&JSON.normaliseMongoId/1)
      # Convert the records to a list
      |> Enum.to_list()
      # Encode the list to a JSON string
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    # Send a 200 OK response with the posts in the body
    |> send_resp(200, posts)
  end

  get "/posts/name/:name" do
    doc = Mongo.find_one(:mongo, "Posts", %{name: name})

    case doc do
      nil ->
        send_resp(conn, 404, "Not Found")

      %{} ->
        post =
          JSON.normaliseMongoId(doc)
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, post)

      {:error, _} ->
        send_resp(conn, 500, "something went wrong")
    end
  end

  post "/post" do
    case conn.body_params do
      %{"name" => name, "content" => content} ->
        case Mongo.insert_one(:mongo, "Posts", %{"name" => name, "content" => content}) do
          {:ok, user} ->
            doc = Mongo.find_one(:mongo, "Posts", %{_id: user.inserted_id})

            post =
              JSON.normaliseMongoId(doc)
              |> Jason.encode!()

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, post)

          {:error, _} ->
            send_resp(conn, 500, "Something went wrong")
        end

      _ ->
        send_resp(conn, 400, '')
    end
  end

  get "/post/:id" do
    doc = Mongo.find_one(:mongo, "Posts", %{_id: BSON.ObjectId.decode!(id)})

    case doc do
      nil ->
        send_resp(conn, 404, "Not Found")

      %{} ->
        post =
          JSON.normaliseMongoId(doc)
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, post)

      {:error, _} ->
        send_resp(conn, 500, "something went wrong")
    end
  end

  put "post/:id" do
    case Mongo.find_one_and_update(
           :mongo,
           "Posts",
           %{_id: BSON.ObjectId.decode!(id)},
           %{
             "$set":
               conn.body_params
               |> Map.take(["name", "content"])
               |> Enum.into(%{}, fn {key, value} -> {"#{key}", value} end)
           },
           return_document: :after
         ) do
      {:ok, doc} ->
        case doc do
          nil ->
            send_resp(conn, 404, "Not Found")

          _ ->
            post =
              JSON.normaliseMongoId(doc)
              |> Jason.encode!()

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, post)
        end

      {:error, _} ->
        send_resp(conn, 500, "Something went wrong")
    end
  end

  delete "post/:id" do
    Mongo.delete_one!(:mongo, "Posts", %{_id: BSON.ObjectId.decode!(id)})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{id: id}))
  end

  # Fallback handler when there was no match
  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
