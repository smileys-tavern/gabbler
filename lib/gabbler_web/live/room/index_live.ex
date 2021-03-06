defmodule GabblerWeb.Room.IndexLive do
  @moduledoc """
  Liveview when someone is in a generic (non-special, like tag tracker) room
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: ["vote", "subscribe"]
  use GabblerWeb.Live.Room
  use GabblerWeb.Live.Voting
  use GabblerWeb.Live.Konami, timeout: 5000
  import Gabbler.Live.SocketUtil, only: [no_reply: 1]

  alias Gabbler.Room, as: GabblerRoom
  alias Gabbler.Subscription, as: GabSub

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
  def handle_info(%{event: "comment_count", id: post_id, count: count}, %{assigns: assigns} = socket) do
    if meta = Map.get(assigns.post_metas, post_id) do
      socket
      |> assign(post_metas: Map.put(assigns.post_metas, post_id, %{meta | comments: count}))
    else
      socket
    end
  end

  @impl true
  def handle_info(%{event: "user_timeout", user: name, hash: hash}, %{assigns: assigns} = socket) do
    assign(socket, timeouts: Map.put(assigns.timeouts, name, hash))
    |> no_reply()
  end

  # PRIV
  #############################
  defp init(%{assigns: %{room: room, posts: posts}} = socket, _, _) do
    assign(socket,
      post_metas: Gabbler.Post.map_metas(posts),
      users: Gabbler.Post.map_users(posts),
      timeouts: GabblerRoom.get_timeouts(room)
    )
  end

  defp init(%{assigns: %{room: nil}} = socket, _, _), do: socket

  defp init(%{assigns: %{mode: :new, room: %{id: id}}} = socket, params, session) do
    posts = Gabbler.Post.list(by_room: id, order_by: :inserted_at, limit: 20)

    init(assign(socket, :posts, posts), params, session)
  end

  defp init(%{assigns: %{mode: :live, room: %{id: id, name: name}}} = socket, params, session) do
    posts = Gabbler.Post.list(by_room: id, order_by: :inserted_at, limit: 20)

    GabSub.subscribe("room_live:#{name}")

    init(assign(socket, :posts, posts), params, session)
  end

  defp init(%{assigns: %{mode: _, room: %{id: id}}} = socket, params, session) do
    posts = Gabbler.Post.list(by_room: id, order_by: :score_private, limit: 20)

    assign(socket, :posts, posts)
    |> init(params, session)
  end

  defp assign_new_post(%{assigns: %{posts: posts, post_metas: metas}} = socket, post, meta) do
    assign(socket, posts: [post | posts], post_metas: Map.put(metas, post.id, meta))
  end
end
