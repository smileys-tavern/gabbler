defmodule Gabbler.TagTracker do
  @moduledoc """
  Tag Tracker (Track-a-Tag!) is an application responsible for keeping data structures that maintain state on
  the latest trending posts, in accordance with their tags and popularity.

  NOTE: The presence of an application instead of just a genserver served by gabbler is mainly to promote future
  additions where the work is distributed further to solve potential scaling situations.
  """
  alias Gabbler.Post.Meta
  alias GabblerData.{Post, PostMeta}
  alias Gabbler.Accounts.User

  @doc """
  Add a new tag or set of tags from a new post
  """
  def add_tags(%Post{} = post, %PostMeta{tags: tags}) do
    for tag <- Meta.filter_tags(tags) do
      cast(:add, {tag, post})
    end
  end

  @doc """
  Get stored tags either by a specific algorithm such as trending, random or specify
  a tag. :trending, :random and "tagname" are all valid. The user asking for tags must
  be specified so they can have the result broadcast
  """
  def get(retrieve_type, %User{id: id}) do
    cast(:get, {retrieve_type, user_channel(id)})
  end

  def get(retrieve_type, channel_name) when is_binary(channel_name) do
    cast(:get, {retrieve_type, channel_name})
  end

  @doc """
  Update a tag with additional score, likely from a vote
  """
  def update(tag, score) do
    cast(:update, {tag, score})
  end

  @doc """
  Instruct the server to sort what is currently in state

  NOTE: that sort is meant to be a larger operation on state. Take care on how often it is called
  """
  def sort(), do: cast(:sort)

  @doc """
  Server name for tag service
  NOTE: susceptable to change as we add more servers to increase the scaling options
  """
  def server_name(), do: "TAG_TRACKER"

  @doc """
  Get the channel name a user can use to subscribe to information from the tag server
  """
  def user_channel(user_id) when is_integer(user_id), do: user_channel(Integer.to_string(user_id))
  def user_channel(user_id), do: "tags:#{user_id}"
  def tag_channel(tag), do: "tag:#{tag}"

  # PRIVATE FUNCTIONS
  ###################
  defp cast(action, args \\ [])

  defp cast(action, args) when is_atom(action) do
    case :syn.whereis(server_name()) do
      :undefined ->
        nil

      pid ->
        case args do
          [] -> GenServer.cast(pid, action)
          _ -> GenServer.cast(pid, {action, args})
        end
    end
  end
end
