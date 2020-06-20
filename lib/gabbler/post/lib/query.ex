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
  def list(opts), do: QueryPost.list(opts)

  @impl true
  def map_meta(posts), do: QueryPost.map_meta(posts)

  @impl true
  def map_rooms(posts), do: QueryPost.map_rooms(posts)

  @impl true
  def map_users(posts), do: QueryPost.map_users(posts)

  @impl true
  def create(changeset, changeset_meta), do: QueryPost.create(changeset, changeset_meta)

  @impl true
  def create_reply(changeset), do: QueryPost.create_reply(changeset)

  @impl true
  def update(changeset), do: QueryPost.update(changeset)

  @impl true
  def update_meta(changeset), do: QueryPost.update_meta(changeset)

  @impl true
  def increment_score(post, amt, amt_priv), do: QueryPost.increment_score(post, amt, amt_priv)

  @impl true
  def comment_count(post), do: QueryPost.comment_count(post)

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