defmodule GabblerWeb.PageController do
  use GabblerWeb, :controller

  def about(conn, _params) do
    render(conn, "about.html")
  end
end
