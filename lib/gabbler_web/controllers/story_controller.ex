defmodule GabblerWeb.StoryController do
  use GabblerWeb, :controller

  alias Gabbler.Subscription, as: GabSub

  plug :put_layout, "iframe.html"


  def new(conn, %{"hash" => hash}) do
    conn
    |> render("new.html", hash: hash)
  end

  def upload(conn, %{"hash" => hash, "images" => images}) do
    story = Gabbler.Story.state(hash)

    for _img <- images do
      _ = GabSub.broadcast("story:#{hash}", %{
        event: "uploading"
      })
    end

    for img <- Enum.reverse(images) do
      Gabbler.Story.add_img(story, img)
    end

    conn
    |> render("new.html", hash: hash)
  end
end
