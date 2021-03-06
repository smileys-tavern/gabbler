defmodule Gabbler.Post.Query do
  @moduledoc """
  The main querying interface for Post. Handles relationship between cache,
  and persistant store.
  """
  @behaviour GabblerData.Behaviour.QueryPost

  import Gabbler, only: [query: 1]

  alias Gabbler.Cache
  alias GabblerData.Query.Post, as: QueryPost

  @cache_default_ttl 86400 # 1 DAY


  @impl true
  def get(id), do: QueryPost.get(id)
  
  @impl true
  def get_by_hash(hash) do
    case Cache.get("POST_#{hash}") do
      nil ->
        query(:post).get_by_hash(hash)
        |> Cache.set_if("POST_#{hash}", ttl: @cache_default_ttl)
        |> post_found?()
      post ->
        {:cachehit, post}
    end
  end

  @impl true
  def get_meta(%{id: id} = post) do
    case Cache.get("POST_META_#{id}") do
      nil -> 
        query(:post).get_meta(post)
        |> Cache.set_if("POST_META_#{id}", ttl: @cache_default_ttl)
        |> post_found?()
      post_meta ->
        {:cachehit, post_meta}
    end
  end

  @impl true
  def list(opts), do: QueryPost.list(opts)

  @impl true
  def map_meta(posts) do
    QueryPost.map_meta(posts)
    |> Enum.reduce(%{}, fn {id, meta}, acc ->
      Map.put(acc, id, %{meta | comments: comment_count(id)})
    end)
  end

  @impl true
  def map_rooms(posts), do: QueryPost.map_rooms(posts)

  @impl true
  def map_users(posts), do: QueryPost.map_users(posts)

  @impl true
  def get_story_images(post_meta), do: QueryPost.get_story_images(post_meta)

  @impl true
  def delete_story_image(public_id), do: QueryPost.delete_story_image(public_id)

  @impl true
  def create_story_image(img), do: QueryPost.create_story_image(img)

  @impl true
  def update_story_image_order(public_id, i), do: QueryPost.update_story_image_order(public_id, i)

  @impl true
  def create(changeset, changeset_meta), do: QueryPost.create(changeset, changeset_meta)

  @impl true
  def create_reply(changeset), do: QueryPost.create_reply(changeset)

  @impl true
  def update(changeset) do
    case QueryPost.update(changeset) do
      {:ok, %{hash: hash}} = result ->
        _ = Cache.delete("POST_#{hash}")
        result
      error->
        error
    end
  end

  @impl true
  def update_meta(changeset) do 
    case QueryPost.update_meta(changeset) do
      {:ok, %{id: id}} = result ->
        _ = Cache.delete("POST_META_#{id}")
        result
      error ->
        error
    end
  end

  @impl true
  def increment_score(post, amt, amt_priv), do: QueryPost.increment_score(post, amt, amt_priv)

  @doc """
  Increment a counter to mark a new comment under a comment. Returns the new count
  """
  def tally_comment(post_id, amount \\ 1) do
    Cache.update_counter("CMT_CNT_#{post_id}", amount)
  end

  @impl true
  def comment_count(%{id: id}), do: Cache.get("CMT_CNT_#{id}")

  def comment_count(id), do: Cache.get("CMT_CNT_#{id}")

  @impl true
  def page_count(post), do: QueryPost.page_count(post)
  
  @impl true
  def thread(post, mode, page \\ 1, level \\ 1, opts \\ []), 
    do: QueryPost.thread(post, mode, page, level, opts)

  # PRIVATE FUNCTIONS
  ###################
  defp post_found?(nil), do: {:error, :post_not_found}
  defp post_found?(post), do: {:ok, post}
end