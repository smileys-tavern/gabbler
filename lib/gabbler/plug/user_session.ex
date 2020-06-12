defmodule Gabbler.Plug.UserSession do
  @moduledoc """
  Puts the current user in the connection object for client consumption
  """
  import Plug.Conn

  alias Gabbler.Accounts.User


  def init(_), do: :ok

  def call(%{assigns: %{user: %User{}}} = conn, _) do
    IO.inspect "USER STILL"
    IO.inspect conn
    conn 
    |> assign(:temp_token, nil)
  end

  def call(conn, _default) do
    {conn, token} = gen_temp_token(conn)

    assign(conn, :user, nil)
    |> assign(:temp_token, token)
  end

  defp gen_temp_token(%{remote_ip: {num1, num2, num3, num4}} = conn) do
    {_, _, micro} = :os.timestamp()

    case Plug.Conn.get_session(conn, "temp_token") do
      nil ->
        token =
          Hashids.new(salt: "gabbler_temp_token", min_len: 16)
          |> Hashids.encode([micro, num1, num2, num3, num4])

        _ = Plug.Conn.put_session(conn, "temp_token", token)

        {conn, token}

      token ->
        {conn, token}
    end
  end

  defp gen_temp_token(conn), do: conn
end
