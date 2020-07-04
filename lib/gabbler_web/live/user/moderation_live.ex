defmodule GabblerWeb.User.ModerationLive do
  @moduledoc """
  Moderation area for a user to perform power moderation
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: [:_page]
  use GabblerWeb.Live.Voting
  import Gabbler.Live.SocketUtil, only: [assign_to: 3, no_reply: 1]

  alias Gabbler.Room, as: GabblerRoom
  alias Gabbler.Post, as: GabblerPost
  alias Gabbler.User, as: GabblerUser

  @max_posts_per_room 10

  @impl true
  def mount(params, session, socket) do
    {:ok, init(socket, params, session)}
  end

  @impl true
  def handle_info(%{event: "new_post", payload: %{post: post, meta: meta}}, socket) do
    assign_new_post(socket, post, meta)
    |> no_reply()
  end

  @impl true
  def handle_event("toggle_room", %{"name" => name}, socket) do
    socket
    |> toggle_room(name)
    |> no_reply()
  end

  @impl true
  def handle_event("user_timeout", %{"name" => name, "hash" => hash}, %{assigns: assigns} = socket) do
    post = GabblerPost.get_post(hash)
    room = assigns.rooms[post.room_id]

    if post && GabblerUser.moderating?(assigns.user, room) do
      _ = room
      |> GabblerRoom.user_timeout(GabblerUser.get_by_name(name), hash)
      
      socket
      |> put_flash(:info, name <> gettext(" is in a timeout"))
      |> no_reply()
    else
      no_reply(socket)
    end
  end

  @impl true
  def handle_event("user_ban", %{"name" => name, "hash" => hash}, %{assigns: assigns} = socket) do
    post = GabblerPost.get_post(hash)
    room = assigns.rooms[post.room_id]

    if post && GabblerUser.moderating?(assigns.user, room) do
      _ = room
      |> GabblerRoom.user_ban(GabblerUser.get_by_name(name))
      
      socket
      |> put_flash(:info, name <> " is banned for life from " <> room.name)
      |> no_reply()
    else
      no_reply(socket)
    end
  end

  # PRIV
  #############################
  defp init(%{assigns: %{user: user}} = socket, _, _) do
    GabblerUser.mod_list(user)
    |> assign_to(:moderating, socket)
    |> assign(room_mode: %{}, posts: %{}, post_metas: %{}, users: %{}, rooms: %{})
    |> init_rooms()
  end

  defp init(socket, _, _), do: socket

  defp init_rooms(%{assigns: %{moderating: moderating}} = socket) do
    moderating
    |> Enum.reduce(socket, fn {_, %{id: id, name: name} = room}, %{assigns: assigns} = socket ->
      posts = GabblerRoom.latest_posts(room)

      socket
      |> assign(:room_mode, Map.put(assigns.room_mode, name, "off"))
      |> assign(:rooms, Map.put(assigns.rooms, id, room))
      |> assign(:posts, Map.put(assigns.posts, id, posts))
      |> assign(:post_metas, Map.merge(assigns.post_metas, GabblerPost.map_metas(posts)))
      |> assign(:users, Map.merge(assigns.users, GabblerPost.map_users(posts)))
    end)
  end

  defp toggle_room(%{assigns: %{room_mode: room_modes}} = socket, name) do
    case Map.get(room_modes, name) do
      "off" -> 
        GabSub.subscribe("room_live:#{name}")
        assign(socket, room_mode: %{room_modes | name => "on"})
      "on" -> 
        GabSub.unsubscribe("room_live:#{name}")
        assign(socket, room_mode: %{room_modes | name => "off"})
      _ ->
        socket
    end
  end

  defp assign_new_post(%{assigns: assigns} = socket, post, meta) do
    updated_posts = [post|assigns.posts[post.room_id]]
    |> Enum.take(@max_posts_per_room)

    socket
    |> assign(posts: %{assigns.posts | post.room_id => updated_posts})
    |> assign(post_metas: Map.put(assigns.metas, post.id, meta))
  end
end
