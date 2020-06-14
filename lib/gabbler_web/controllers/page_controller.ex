defmodule GabblerWeb.PageController do
  use GabblerWeb, :controller

  import Gabbler, only: [query: 1]
  alias Gabbler.Live, as: GabblerLive
  

  def about(conn, _params) do
    render(conn, "about.html")
  end
end
