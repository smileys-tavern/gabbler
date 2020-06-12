defmodule GabblerWeb.Live.House.TagTracker do
  @moduledoc """
  The tag tracking special room
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Voting
  import Gabbler, only: [query: 1]
  import GabblerWeb.Gettext

  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.TagTracker
  alias Gabbler.Accounts.User

  def render(assigns) do
    ~L"""
      <%= Phoenix.View.render(GabblerWeb.PageView, "tag_tracker.html", assigns) %>
    """
  end

  def handle_info(%{event: "tag_list", list: posts}, %{assigns: %{posts: curr_posts} = assigns} = socket) do
    {:noreply,
     assign(socket,
       posts: Enum.uniq(posts ++ curr_posts),
       post_metas: Map.merge(query(:post).map_meta(posts), assigns.post_metas),
       users: Map.merge(query(:post).map_users(posts), assigns.users),
       rooms: Map.merge(query(:post).map_rooms(posts), assigns.rooms)
     )}
  end

  def handle_event(
        "submit",
        %{"tag" => %{"tracker" => tag}},
        %{assigns: %{tag_channel: channel}} = socket
      ) do
    GabSub.unsubscribe(channel)

    new_channel = TagTracker.tag_channel(tag)

    GabSub.subscribe(new_channel)

    _ = TagTracker.get(tag, new_channel)

    {:noreply, assign(socket, posts: [], tag_channel: new_channel, current_tag: tag)}
  end

  def mount(_params, session, socket) do
    {channel, _user} =
      case session do
        %{"user" => %User{id: id} = user} -> {TagTracker.user_channel(id), user}
        %{"temp_token" => token} -> {TagTracker.user_channel(token), token}
      end

    GabSub.subscribe(channel)

    _ = TagTracker.get(:trending, channel)

    {:ok,
     assign(socket,
       tag_channel: channel,
       current_tag: gettext("all trending"),
       posts: [],
       post_metas: %{},
       users: %{},
       rooms: %{}
     )}
  end

  # PRIV
  #############################
end
