defmodule Gabbler.Story.Images do
  @moduledoc """
  Module for uploading story images. Enforces the uploading rules
  """
  @thumb_dimension 80
  @story_width 800

  alias GabblerData.StoryImage
  alias Gabbler.Story.Image

  @doc """
  Upload a jpeg and return a 4-tuple with the original file name, public_id and the thumb
  and image urls, or an error with the files name. public_id is a unique identifier for
  the asset.
  """
  def upload(story, %Plug.Upload{content_type: "image/jpg", filename: name, path: path}) do
    upload(story, name, path)
  end

  def upload(story, %Plug.Upload{content_type: "image/jpeg", filename: name, path: path}) do
    upload(story, name, path)
  end

  def upload(_, %Plug.Upload{filename: name}), do: {:error, name}

  def upload(%{hash: story_hash} = story, name, path) do
    case Cloudex.upload(path, %{}) do
      {:ok, %{public_id: public_id, bytes: bytes}} ->
        thumb = Cloudex.Url.for(public_id, %{width: @thumb_dimension, height: @thumb_dimension, format: "jpg"})
        image = Cloudex.Url.for(public_id, %{width: @story_width, flags: "keep_iptc"})

        _ = %StoryImage{public_id: public_id, url: image, thumb: thumb, story_hash: story_hash}
        |> StoryImage.changeset()
        |> Gabbler.Post.create_story_image()

        {:ok, name, %Image{id: public_id, url: image, thumb: thumb, size: bytes}}
      {:error, _error} ->
        {:error, name}
    end
  end

  @doc """
  Remove the image from the content service
  """
  def destroy_image(public_id) do
    case Cloudex.delete(public_id) do
      {:ok, _} ->
        Gabbler.Post.delete_story_image(public_id)
      error ->
        error
    end
  end
end