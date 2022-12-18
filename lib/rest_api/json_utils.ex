defmodule RestApi.JsonUtils do
  @moduledoc """
    JSON Utilities
  """

  @doc """
    Extend BSON to encode MongoDB ObjectIds to string
  """
  defimpl Jason.Encoder, for: BSON.ObjectId do
    def encode(id, options) do
      # Convert the binary id to string 
      BSON.ObjectId.encode!(id)
      # encode the string to json
      |> Jason.Encoder.encode(options)
    end
  end

  def normaliseMongoId(doc) do
    doc
    # Set the id property to the value of _id
    |> Map.put('id', doc["_id"])
    # Delete the _id property
    |> Map.delete("_id")
  end
end
