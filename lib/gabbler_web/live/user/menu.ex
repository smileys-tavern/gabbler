defmodule GabblerWeb.Live.User.Menu do
  @moduledoc """
  Authentication live view to manage the ui based on a users status and actions
  """
  use Phoenix.LiveView
  import Gabbler, only: [query: 1]
  import Gabbler.Live.SocketUtil
  import GabblerWeb.Gettext

  alias Gabbler.Accounts.User
  alias Gabbler.Subscription, as: GabSub
  
  @max_activity_shown 5


  def render(assigns) do
    ~L"""
      <%= Phoenix.View.render(GabblerWeb.UserView, "menu.html", assigns) %>
    """
  end
  
  @doc """
  Set default form and status of creation
  """
  def mount(_params, session, socket), do: {:ok, init(session, socket)}

  def handle_info(:warning_expire, socket), do: {:noreply, assign(socket, warning: nil)}

  def handle_info(:info_expire, socket), do: {:noreply, assign(socket, info: nil)}

  def handle_info(%{event: "subscribed"}, %{assigns: %{user: user}} = socket) do
    user
    |> Gabbler.User.subscriptions()
    |> assign_to(:subscriptions, socket)
    |> no_reply()
  end

  def handle_info(%{event: "unsubscribed"}, %{assigns: %{user: user}} = socket) do
    user
    |> Gabbler.User.subscriptions()
    |> assign_to(:subscriptions, socket)
    |> no_reply()
  end

  def handle_info(%{event: "new_post", payload: %{post: post}}, %{assigns: %{posts: posts, rooms: rooms}} = socket) do
    rooms
    |> Map.put(post.id, Gabbler.Room.get(post.room_id))
    |> assign_to(:rooms, socket)
    |> assign(posts: [post|posts])
    |> no_reply()
  end

  def handle_info(%{event: "mod_request", payload: %{id: room_name}}, %{assigns: %{activity: activity}} = socket) do
    [{room_name, "mod_request"}|activity]
    |> Enum.take(@max_activity_shown)
    |> assign_to(:activity, socket)
    |> no_reply()
  end

  def handle_info(%{event: "banned_for_life", room_name: name}, socket) do
    assign(socket, info: name <> gettext(": you are banned for life"))
    |> no_reply()
  end

  def handle_info(%{event: "unbanned", room_name: name}, socket) do
    assign(socket, info: name <> gettext(": you are unbanned"))
    |> no_reply()
  end

  def handle_info(%{event: "reply", payload: %{id: post_id}}, socket) do
    assign_activity(socket, post_id)
    |> no_reply()
  end

  def handle_info(%{event: "warning", msg: msg}, socket) do
    Process.send_after(self(), :warning_expire, 4000)

    assign(socket, warning: msg)
    |> no_reply()
  end

  def handle_info(%{event: "info", msg: msg}, socket) do
    Process.send_after(self(), :info_expire, 4000)

    # TODO: create a container for the message and update state to activate it
    assign(socket, info: msg)
    |> no_reply()
  end

  def handle_event("login", _, %{assigns: %{temp_token: token}} = socket) do
    GabSub.broadcast("user:#{token}", %{event: "login_show"})

    {:noreply, socket}
  end

  def handle_event("toggle_menu", _, %{assigns: %{menu_open: false}} = socket) do
    assign(socket, menu_open: true)
    |> no_reply()
  end

  def handle_event("toggle_menu", _, %{assigns: %{menu_open: true}} = socket) do
    assign(socket, menu_open: false)
    |> no_reply()
  end

  def handle_event("accept_mod", %{"id" => room_name}, %{assigns: %{user: user}} = socket) do
    user
    |> Gabbler.User.add_mod(Gabbler.Room.get_room(room_name))
    |> assign_always(:moderating, Gabbler.User.moderating(user), socket)
    |> assign(activity: Gabbler.User.get_activity(user))
    |> no_reply()
  end

  def handle_event("decline_mod", %{"id" => room_name}, %{assigns: %{user: user}} = socket) do
    user
    |> Gabbler.User.decline_mod(Gabbler.Room.get_room(room_name))
    |> assign_always(:activity, Gabbler.User.get_activity(user), socket)
    |> no_reply()
  end

  # PRIV
  #############################
  defp init(session, socket) do
    assign_user(socket, session)
    |> subscribe_user()
    |> assign_menu_defaults()
    |> assign_user_info()
  end

  defp assign_user(socket, %{"user" => %User{} = user}) do
    assign(socket, user: user, temp_token: nil)
  end

  defp assign_user(socket, %{"temp_token" => temp_token}) do
    assign(socket, user: nil, temp_token: temp_token)
  end

  defp assign_user_info(%{assigns: %{user: %User{} = user}} = socket) do
    activity = Gabbler.User.get_activity(user)
    posts = Gabbler.User.posts(user) |> hash_to_post()

    socket = assign(socket,
      posts: posts,
      rooms: Gabbler.Post.map_rooms(posts),
      activity: [])

    activity
    |> Enum.reduce(socket, fn {post_id, type}, socket ->
      case type do
        "reply" -> assign_activity(socket, post_id)
        _ -> socket
      end
    end)
    |> assign(
      subscriptions: Gabbler.User.subscriptions(user),
      moderating: Gabbler.User.moderating(user))
  end

  defp assign_user_info(socket), do: socket

  defp assign_menu_defaults(socket) do
    assign(socket, 
      menu_open: false,
      warning: nil,
      info: nil)
  end

  defp subscribe_user(%{assigns: %{user: %{id: id}}} = socket) do
    GabSub.subscribe("user:#{id}")

    socket
  end

  defp subscribe_user(socket), do: socket

  defp assign_activity(%{assigns: %{posts: posts, rooms: rooms, activity: activity}} = socket, post_id) do
    case Map.get(rooms, post_id) do
      nil ->
        post = Gabbler.Post.get_by_id(post_id)

        socket = Enum.take([{post_id, "reply"} | activity], @max_activity_shown)
        |> assign_to(:activity, socket)

        Map.put(rooms, post_id, Gabbler.Room.get(post.room_id))
        |> assign_to(:rooms, socket)
        |> assign(posts: [post|posts])

      _ ->
        # Post still exists in feed, can show in activity
        Enum.take([{post_id, "reply"}|activity], @max_activity_shown)
        |> assign_to(:activity, socket)
    end
  end

  defp hash_to_post(user_posts) do
    Enum.reduce(user_posts, [], fn {hash, _}, acc -> [Gabbler.Post.get_post(hash)|acc] end)
    |> Enum.reverse()
  end
end