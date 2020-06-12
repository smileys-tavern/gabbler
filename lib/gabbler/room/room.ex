defmodule Gabbler.Room do
  @moduledoc """
  Each room has it's own server responsible for decaying it's posts and deactivating if the room loses activity
  for long enough. Rooms that aren't used in a long while have their servers expire.

  Memory is used for all room querying by default, backing up to the persistant store.
  """
  import Gabbler, only: [query: 1]

  alias Gabbler.Room.Application, as: RoomApp
  alias Gabbler.Room.RoomState

  @doc """
  Retrieve the room from state.
  """
  def get_room(room_name), do: call(room_name, :get_room)

  @doc """
  Get identifying process id for a room
  """
  def server_name(room_name) when is_binary(room_name), do: {:via, :syn, "ROOM_#{room_name}"}

  # PRIVATE FUNCTIONS
  ###################
  defp call(room_name, action, args \\ nil) do
    case get_room_server_pid(room_name) do
      {:ok, pid} -> GenServer.call(pid, {action, args})
      {:error, _} -> nil
    end
  end

  defp get_room_server_pid(room_name) do
    case :syn.whereis(server_name(room_name)) do
      :undefined ->
        case query(:room).get_by_name(room_name) do
          nil -> 
            {:error, :room_not_found}
          room -> 
            RoomApp.add_child(%RoomState{room: room})
        end
      pid ->
        {:ok, pid}
    end
  end
end