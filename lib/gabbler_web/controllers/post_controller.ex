defmodule GabblerWeb.PostController do
  use GabblerWeb, :controller

  alias Gabbler.Live, as: GabblerLive
  alias Gabbler.Controller, as: GabController

  @live_post_new GabblerWeb.Live.Post.New
  @live_post GabblerWeb.Live.Post.Index


  def new(conn, params) do
    GabController.add_room(%{}, params)
    |> GabController.render_if(["room"], conn, &render_post_new/2)
  end

  def post(conn, params) do
    GabController.add_room(%{}, params)
    |> GabController.add_post(params)
    |> GabController.add_mode(params)
    |> GabController.render_if(["room", "post"], conn, &render_post/2)
  end

  def comment(conn, params) do
    GabController.add_room(%{}, params)
    |> GabController.add_post(params)
    |> GabController.add_mode(params)
    |> GabController.render_if(["room", "post"], conn, &render_post/2)
  end

  # PRIVATE FUNCTIONS
  ###################
  defp render_post_new(conn, session), do: GabblerLive.render(conn, @live_post_new, session)
  defp render_post(conn, session), do: GabblerLive.render(conn, @live_post, session)
end
