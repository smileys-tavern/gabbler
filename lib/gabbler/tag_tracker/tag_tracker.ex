defmodule Gabbler.TagTracker do
  @moduledoc """
  Tag Tracker (Track-a-Tag!) is an application responsible for keeping data structures that maintain state on
  the latest trending posts, in accordance with their tags and popularity.

  NOTE: The presence of an application instead of just a genserver served by gabbler is mainly to promote future
  additions where the work is distributed further to solve potential scaling situations.
  """
  alias GabblerData.{Post, PostMeta, Room}
  alias Gabbler.Accounts.User
  alias Gabbler.Cache
  alias Gabbler.Post.Meta
  alias Gabbler.TagTracker.TopContent

  @ttl_top5 1000 * 60 * 5 # 5 minutes

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
  def get(%User{id: id} = user, retrieve_type) do
    _ = cast(:get, {retrieve_type, user_channel(id)})
    user
  end

  def get(channel_name, retrieve_type) when is_binary(channel_name) do
    _ = cast(:get, {retrieve_type, channel_name})
    channel_name
  end

  @doc """
  Get a list out of memory of the latest 3 tags
  """
  def top_tags(limit \\ 3) do
    case Cache.get("TRENDING_TAGS") do
      nil -> []
      tags -> Enum.slice(tags, 0..limit)
    end
  end

  @doc """
  Retrieve a list of the top content around the site returning it in
  a standard way whether it be a post, story, room or other. Returns as
  TopContent structs
  """
  def top_content() do
    case nil do # Cache.get("TOP5:ALL")
      nil ->
        newest_rooms = Gabbler.Room.newest_rooms(1)

        trending_posts = Gabbler.Post.list(only: :op, order_by: :score_private, limit: 4)

        top_content = populate_top_content(newest_rooms ++ trending_posts, [])
        |> Enum.take(5)

        _ = Cache.set("TOP5:ALL", top_content, ttl: @ttl_top5)

        top_content
      top_content ->
        top_content
    end
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

  defp populate_top_content([], acc), do: Enum.shuffle(acc)

  defp populate_top_content([%Room{title: title, name: name, description: desc}|t], acc) do
    img = case String.split(title, "\"") do
      [_, href, _] -> href
      _ -> nil
    end

    populate_top_content(t, [%TopContent{
      type: :room, 
      url: "/r/#{name}",
      desc: desc,
      imgs: [img]}|acc])
  end

  defp populate_top_content([%Post{room_id: r_id, user_id: u_id, hash: hash} = p|t], acc) do
    user = Gabbler.User.get(u_id)

    room = Gabbler.Room.get(r_id)

    meta = Gabbler.Post.get_meta(p)

    images = Gabbler.Post.get_story_images(meta)
    |> Enum.map(fn %{public_id: pub_id} -> 
      Cloudex.Url.for(pub_id, %{width: 195, height: 215})
    end)
    |> Enum.take(10)

    thumbs = Gabbler.Post.get_story_images(meta)
    |> Enum.map(fn %{public_id: pub_id} -> 
      Cloudex.Url.for(pub_id, %{width: 118, height: 138})
    end)
    |> Enum.take(10)

    ext_url = case meta do
      %{link: nil} -> nil
      %{link: link} -> link
    end

    populate_top_content(t, [%TopContent{
      type: :post,
      url: "/r/#{room.name}/comments/#{hash}/#{p.title}",
      ext_url: ext_url,
      desc: "#{p.title} by #{user.name}",
      imgs: images,
      thumbs: thumbs,
      long: String.slice(p.body, 0, 300)}|acc])
  end
end
