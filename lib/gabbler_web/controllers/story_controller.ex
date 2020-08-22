defmodule GabblerWeb.StoryController do
  use GabblerWeb, :controller

  plug :put_layout, "iframe.html"

  def new(conn, %{"hash" => hash}) do
    conn
    |> render("new.html", hash: hash)
  end

  def upload(conn, %{"hash" => hash, "images" => images} = params) do
    story = Gabbler.Story.state(hash)

    for img <- images do
      Gabbler.Story.add_img(story, img)
    end

    conn
    |> render("new.html", hash: hash)
  end
end