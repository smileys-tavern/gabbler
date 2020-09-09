defmodule GabblerWeb.PagePlugs do
  import Plug.Conn
  import Phoenix.Controller

  def populate_trending(conn, _opts) do
    conn
    |> assign(:trending_tags, Gabbler.TagTracker.top_tags())
  end
end