defmodule GabblerWeb.StoryController do
  use GabblerWeb, :controller

  plug :put_layout, "iframe.html"

  def new(conn, %{"hash" => hash}) do
    _story = Gabbler.Story.state(hash)

    conn
    |> render("new.html", hash: hash)
  end

  def upload(conn, %{"hash" => hash} = params) do
    #[%Plug.Upload{
    #  content_type: "image/jpeg",
    #  filename: "gabbler-post.jpg",
    #  path: "/tmp/plug-1597/multipart-1597629647-126480828948740-1"
    #},..]
    _story = Gabbler.Story.state(hash)

    # Cast Upload to Story which will sequentially process

    # Story server reports results and thumbs from cloudex to a cast

    # Post liveview picks up on Story servers broadcast and updates area below
    # form iframe and post previewer

    conn
    |> render("new.html", hash: hash)
  end
end
