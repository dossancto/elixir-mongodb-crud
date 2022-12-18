defmodule RestApiTest do
  use ExUnit.Case
  use Plug.Test

  @opts RestApi.Router.init([])

  def createPosts() do
    result =
      Mongo.insert_many!(:mongo, "Posts", [
        %{name: "Post 1", content: "Content 1"},
        %{name: "Post 2", content: "Content 2"}
      ])

    result.inserted_ids |> Enum.map(fn id -> BSON.ObjectId.encode!(id) end)
  end

  test "Returns Ok" do
    conn = conn(:get, "/")

    conn = RestApi.Router.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "OK"
  end

  describe "Posts" do
    # The setup callback is called before each test executes and the on_exit after each test is complete
    # We will use this hook to list all the mongo db collections and for each of
    # the collection to clear out the entire collection. This way for every test
    # case we will start from a clean slate
    setup do
      on_exit(fn ->
        Mongo.show_collections(:mongo)
        |> Enum.each(fn col -> Mongo.delete_many!(:mongo, col, %{}) end)
      end)
    end

    test "POST /post should return ok" do
      # Asserts that there are no elements in the db
      assert Mongo.find(:mongo, "Posts", %{}) |> Enum.count() == 0

      conn = conn(:post, "/post", %{name: "Post Fake", content: "This is not a real Post"})
      conn = RestApi.Router.call(conn, @opts)

      # Check if the post was sent
      assert conn.state == :sent

      # Assets that the request is success
      assert conn.status == 200

      assert %{
               "id" => _,
               "content" => "This is not a real Post",
               "name" => "Post Fake"
             } = Jason.decode!(conn.resp_body)

      assert Mongo.find(:mongo, "Posts", %{}) |> Enum.count() == 1
    end

    test "GET /posts should fetch all the posts" do
      createPosts()

      conn = conn(:get, "/posts")
      conn = RestApi.Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      resp = Jason.decode!(conn.resp_body)

      assert Enum.count(resp) == 2

      assert %{
               "id" => _,
               "content" => "Content 1",
               "name" => "Post 1"
             } = Enum.at(resp, 0)

      assert %{
               "id" => _,
               "content" => "Content 2",
               "name" => "Post 2"
             } = Enum.at(resp, 1)
    end

    test "GET /post/:id should fetch a single post" do
      [id | _] = createPosts()

      conn = conn(:get, "/post/#{id}")
      conn = RestApi.Router.call(conn, @opts)

      assert %{
               "id" => _,
               "content" => "Content 1",
               "name" => "Post 1"
             } = Jason.decode!(conn.resp_body)
    end

    test "PUT /post/:id should update a post" do
      [id | _] = createPosts()

      conn = conn(:put, "/post/#{id}", %{content: "Content 3"})
      conn = RestApi.Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      assert %{
               "id" => _,
               "content" => "Content 3",
               "name" => "Post 1"
             } = Jason.decode!(conn.resp_body)
    end

    test "DELETE /ṕost/:id should delete a post" do
      [id | _] = createPosts()

      assert Mongo.find(:mongo, "Posts", %{}) |> Enum.count() == 2

      conn = conn(:delete, "/post/#{id}", %{content: "Content 3"})
      conn = RestApi.Router.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200

      assert Mongo.find(:mongo, "Posts", %{}) |> Enum.count() == 1
    end
  end
end
