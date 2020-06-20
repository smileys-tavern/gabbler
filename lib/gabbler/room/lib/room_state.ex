defmodule Gabbler.Room.RoomState do
  @moduledoc """
  The struct that holds running status of a room
  """
  alias GabblerData.Room

  defstruct room: %Room{}, user_timeout: %{}, decay_mode: :rapid, notice: nil
end