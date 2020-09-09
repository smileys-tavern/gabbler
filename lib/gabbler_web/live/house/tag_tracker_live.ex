defmodule GabblerWeb.House.TagTrackerLive do
  @moduledoc """
  The tag tracking special room
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: ["no-op"]
  use GabblerWeb.Live.Voting
  import Gabbler.Live.SocketUtil, only: [no_reply: 1, assign_to: 3]
  import GabblerWeb.Gettext

  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.TagTracker

  @impl true
  def handle_info(%{event: "tag_list", payload: %{list: posts}}, %{assigns: %{posts: curr_posts} = assigns} = socket) do
     socket
     |> assign(
       posts: Enum.uniq(posts ++ curr_posts),
       post_metas: Map.merge(Gabbler.Post.map_meta(posts), assigns.post_metas),
       users: Map.merge(Gabbler.Post.map_users(posts), assigns.users),
       rooms: Map.merge(Gabbler.Post.map_rooms(posts), assigns.rooms)
     )
     |> no_reply()
  end

  @impl true
  def handle_event(
    "submit",
    %{"tag" => %{"tracker" => tag}},
    %{assigns: %{tag_channel: channel}} = socket
  ) do
    _ = GabSub.unsubscribe(channel)
    
    TagTracker.tag_channel(tag)
    |> GabSub.subscribe()
    |> TagTracker.get(tag)
    |> assign_to(:tag_channel, socket)
    |> assign(posts: [], current_tag: tag)
    |> no_reply()
  end

  @impl true
  def mount(params, session, socket) do
    {:ok, init(default_assigns(socket), params, session)}
  end

  # PRIV
  #############################
  defp init(socket, %{"tag" => tag}, session) do
    TagTracker.tag_channel(tag)
    |> GabSub.subscribe()
    |> TagTracker.get(tag)
    |> assign_to(:tag_channel, socket)
    |> assign(posts: [], current_tag: tag)
    |> init(%{}, session)
  end

  defp init(%{assigns: %{user: %{id: user_id}, temp_token: nil}} = socket, _, _) do
    TagTracker.user_channel(user_id)
    |> GabSub.subscribe()
    |> TagTracker.get(:trending)
    |> assign_to(:tag_channel, socket)
  end

  defp init(%{assigns: %{temp_token: token}} = socket, _, _) do
    TagTracker.user_channel(token)
    |> GabSub.subscribe()
    |> TagTracker.get(:trending)
    |> assign_to(:tag_channel, socket)
  end

  defp default_assigns(socket) do
    socket
    |> assign(current_tag: gettext("all trending"))
    |> assign(posts: [])
    |> assign(post_metas: %{}, users: %{}, rooms: %{})
  end
end
