defmodule Gabbler.Live do
  @moduledoc """
  Gabbler specific handling of live view functionality
  """
  import Phoenix.LiveView.Controller, only: [live_render: 3]

  @doc """
  Render a live view, placing some defaults based on the connection info
  """
  def render(%{assigns: %{user: user, temp_token: token}} = conn, module, session \\ %{}) do
    session = session
    |> Map.put("temp_token", token)
    |> Map.put("user", user)

    live_render(conn, module, session: session)
  end
end
