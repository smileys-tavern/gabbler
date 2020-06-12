defmodule GabblerWeb.PageController do
  use GabblerWeb, :controller

  import Gabbler, only: [query: 1]
  alias Gabbler.Live, as: GabblerLive


  def index(conn, _params) do
    posts = query(:post).list(order_by: :score_private, limit: 20, only: :op)

    GabblerLive.render(conn, GabblerWeb.Live.House.All, %{
      "posts" => posts,
      "post_metas" => query(:post).map_meta(posts),
      "users" => query(:post).map_users(posts),
      "rooms" => query(:post).map_rooms(posts)})
  end

  def tag_tracker(%{assigns: %{user: user}} = conn, _params) do
    GabblerLive.render(conn, GabblerWeb.Live.House.TagTracker, %{"user" => user})
  end

  def about(conn, _params) do
    render(conn, "about.html")
  end
end
