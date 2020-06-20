defmodule Gabbler.Room do
  @moduledoc """
  Each room has it's own server responsible for decaying it's posts and deactivating if the room loses activity
  for long enough. Rooms that aren't used in a long while have their servers expire.

  The fast access app cache is used when possible, falling back to the database. Any time
  the database is used the Room Server has it's room info refreshed.
  """
  alias Gabbler.Room.Application, as: RoomApp
  alias Gabbler.Room.Query, as: QueryRoom
  alias Gabbler.Room.RoomState
  alias GabblerData.Room

  @doc """
  Retrieve the room. If in cache return, else refresh Room Server's info
  with results of query/cache reseed.
  """
  def get_room(room_name) do
    case QueryRoom.get_by_name(room_name) do
      {:cachehit, room} -> room
      {:ok, room} -> call(room, :update_room)
      {:error, _} -> nil
    end
  end

  def get(id), do: QueryRoom.get(id)

  @doc """
  Create a room using data store
  """
  def create_room(changeset), do: QueryRoom.create(changeset)

  @doc """
  Get identifying process id for a room
  """
  def server_name(room_name) when is_binary(room_name), do: {:via, :syn, "ROOM_#{room_name}"}

  # PRIVATE FUNCTIONS
  ###################
  defp call(%Room{} = room, :update_room) do
    case get_room_server_pid(room) do
      {:ok, pid} -> GenServer.call(pid, {:update_room, room})
      {:error, _} -> nil
    end
  end

  defp call(room_name, action, args \\ nil) do
    case get_room_server_pid(room_name) do
      {:ok, pid} -> GenServer.call(pid, {action, args})
      {:error, _} -> nil
    end
  end

  defp get_room_server_pid(%Room{name: name} = room) do
    case :syn.whereis(server_name(name)) do
      :undefined -> RoomApp.add_child(%RoomState{room: room})
      pid -> {:ok, pid}
    end
  end

  defp get_room_server_pid(room_name) do
    case :syn.whereis(server_name(room_name)) do
      :undefined ->
        case QueryRoom.get_by_name(room_name) do
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