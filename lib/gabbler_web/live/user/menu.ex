defmodule GabblerWeb.Live.User.Menu do
  @moduledoc """
  Authentication live view to manage the ui based on a users status and actions
  """
  use Phoenix.LiveView
  import Gabbler, only: [query: 1]
  import GabblerWeb.Gettext
  import Gabbler.Live.SocketUtil, only: [no_reply: 1, assign_to: 3]

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

  def handle_info(%{event: "subscribed", room_name: name}, %{assigns: %{user: user}} = socket) do
    Gabbler.User.activity_subscribed(user, name)
    |> assign_to(:subscriptions, socket)
    |> no_reply()
  end

  def handle_info(%{event: "unsubscribed", room_name: name}, %{assigns: %{user: user}} = socket) do
    Gabbler.User.activity_unsubscribed(user, name)
    |> assign_to(:subscriptions, socket)
    |> no_reply()
  end

  def handle_info(%{event: "new_post", post: post}, %{assigns: %{posts: posts, rooms: rooms}} = socket) do
    Map.put(rooms, post.id, query(:room).get(post.room_id))
    |> assign_to(:rooms, socket)
    |> assign(posts: [post|posts])
    |> no_reply()
  end

  def handle_info(%{event: "mod_request", id: room_name}, %{assigns: %{activity: activity}} = socket) do
    Enum.take([{room_name, "mod_request"}|activity], @max_activity_shown)
    |> assign_to(:activity, socket)
    |> no_reply()
  end

  def handle_info(%{event: "reply", id: post_id}, socket) do
    assign_activity(socket, post_id)
    |> no_reply()
  end

  def handle_info(%{event: "warning", msg: msg}, socket) do
    Process.send_after(self(), :warning_expire, 4000)

    # TODO: create a container for the message and update state to activate it
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

  def handle_event("accept_mod", %{"id" => room_name}, socket) do
    accept_mod_invite(socket, query(:room).get(room_name), room_name)
    |> broadcast_mod_invite()
    |> no_reply()
  end

  def handle_event("decline_mod", %{"id" => room_name}, %{assigns: %{user: user}} = socket) do
    assign(socket, activity: Gabbler.User.remove_activity(user, room_name))
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
    posts = Gabbler.User.posts(user)
    |> hash_to_post()

    assign(socket,
      posts: posts,
      subscriptions: Gabbler.User.subscriptions(user),
      moderating: Gabbler.User.moderating(user),
      rooms: query(:post).map_rooms(posts),
      activity: Gabbler.User.get_activity(user))
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
        post = query(:post).get(post_id)

        socket = Enum.take([{post_id, "reply"} | activity], @max_activity_shown)
        |> assign_to(:activity, socket)

        Map.put(rooms, post_id, query(:room).get(post.room_id))
        |> assign_to(:rooms, socket)
        |> assign(posts: [post|posts])

      _ ->
        # Post still exists in feed, can show in activity
        Enum.take([{post_id, "reply"}|activity], @max_activity_shown)
        |> assign_to(:activity, socket)
    end
  end

  defp accept_mod_invite(%{assigns: %{user: user}} = socket, {:ok, _}, room_name) do
    {:ok, assign(socket, Gabbler.User.remove_activity(user, room_name))}
  end

  defp accept_mod_invite(%{assigns: %{user: user}} = socket, {:error, _}, room_name) do
    {:error, assign(socket, Gabbler.User.remove_activity(user, room_name))}
  end

  defp broadcast_mod_invite({:ok, %{assigns: %{user: user}} = socket}) do
    Gabbler.User.notify(user, gettext("added as moderator"))

    socket
  end

  defp broadcast_mod_invite({:error, %{assigns: %{user: user}} = socket}) do
    Gabbler.User.notify(user, gettext("room no longer exists"), "warning")

    socket
  end

  defp hash_to_post(user_posts) do
    Enum.reduce(user_posts, [], fn {hash, _}, acc -> [query(:post).get_by_hash(hash)|acc] end)
    |> Enum.reverse()
  end
end