defmodule GabblerWeb.House.AllLive do
  @moduledoc """
  Liveview for the house All page
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: ["vote"]
  use GabblerWeb.Live.Voting

  @impl true
  def mount(params, session, socket) do
    {:ok, init(socket, params, session)}
  end

  # PRIVATE FUNCTIONS
  ###################
  defp init(socket, _, session) do
    posts = query(:post).list(order_by: :score_private, limit: 20, only: :op)

    assign(socket, 
      posts: posts,
      post_metas: query(:post).map_meta(posts),
      rooms: query(:post).map_rooms(posts),
      users: query(:post).map_users(posts))
  end
end