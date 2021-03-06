defmodule Gabbler.Plug.Room do
  @moduledoc """
  Assigns to the connection based on parameters related to rooms
  """
  import Plug.Conn
  

  def init(_), do: :ok

  def call(conn, _default) do
    assign(conn, :user, nil)
    |> assign(:temp_token, nil)
  end
end
