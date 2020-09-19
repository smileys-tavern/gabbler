defmodule GabblerWeb.House.AllLive do
  @moduledoc """
  Liveview for the house All page
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: ["vote"]
  use GabblerWeb.Live.Voting

  @banner_uptime 1000 * 5
  @max_trends 5

  @impl true
  def handle_info(:inc_selected, %{assigns: %{selected: selected}} = socket) do
    new_selected = cond do
      selected >= (@max_trends - 1) -> 0
      true -> selected + 1
    end

    Process.send_after(self(), :inc_selected, @banner_uptime)

    socket
    |> assign(selected: new_selected)
    |> no_reply()
  end

  @impl true
  def mount(params, session, socket) do
    {:ok, init(socket, params, session)}
  end

  # PRIVATE FUNCTIONS
  ###################
  defp init(socket, _, _) do
    posts = Gabbler.Post.list(order_by: :score_private, limit: 20, only: :op)

    Process.send_after(self(), :inc_selected, @banner_uptime)

    assign(socket, 
      posts: posts,
      post_metas: Gabbler.Post.map_meta(posts),
      rooms: Gabbler.Post.map_rooms(posts),
      users: Gabbler.Post.map_users(posts),
      selected: 0,
      max_trends: @max_trends)
  end
end