defmodule GabblerWeb.Live.House.All do
  @moduledoc """
  Liveview for the house All page
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: ["vote"]
  use GabblerWeb.Live.Voting

  @impl true
  def render(assigns) do
    ~L"""
      <%= Phoenix.View.render(GabblerWeb.PageView, "index.html", assigns) %>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    {:ok, init(session, socket)}
  end

  # PRIVATE FUNCTIONS
  ###################
  defp init(session, socket) do
    assign(socket, 
      posts: Map.get(session, "posts", []),
      post_metas: Map.get(session, "post_metas", []),
      users: Map.get(session, "users", []),
      rooms: Map.get(session, "rooms", []),
      user: Map.get(session, "user", nil))
  end
end