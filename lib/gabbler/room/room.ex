defmodule Gabbler.Room do
  @moduledoc """
  Each room has it's own server responsible for decaying it's posts and deactivating if the room loses activity
  for long enough. Rooms that aren't used in a long while have their servers expire.

  The fast access app cache is used when possible, falling back to the database. Any time
  the database is used the Room Server has it's room info refreshed.
  """
  import GabblerWeb.Gettext

  alias Gabbler.Room.Application, as: RoomApp
  alias Gabbler.Room.Query, as: QueryRoom
  alias Gabbler.Room.RoomState
  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.User, as: GabblerUser
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
  Give a user a timeout! They cannot post for the duration in this room
  """
  def user_timeout(%{name: name} = room, %{name: user_name} = user, hash) do
    timeouts = call(room, :user_timeout, {user, hash})
    _ = GabblerUser.broadcast(user, gettext("you are in a timeout from ") <> name, "info")

    room
    |> QueryRoom.update_timeouts(timeouts)
    |> broadcast_live(%{event: "user_timeout", user: user_name, hash: hash})
  end

  def user_ban(%{id: id, name: name} = room, %{id: user_id}) do
    # TODO: formalize channels in protocol so they aren't ad-hoc string codes
    QueryRoom.ban_for_life(id, user_id)
    |> broadcast_if(room, "user:#{user_id}", %{event: "banned_for_life", room_name: name})
  end

  def user_unban(%{id: id} = room, %{id: user_id}) do
    _ = QueryRoom.unban(id, user_id)
    room
  end

  def banned?(%{id: id}, %{id: user_id}), do: QueryRoom.banned?(id, user_id)

  @doc """
  Return true/false based on if the user is in a timeout currently. Handles
  refreshing the cache if not found (to avoid hitting room server with large
  request load (may not prove necessary))
  """
  def in_timeout?(room, user) do
    room
    |> QueryRoom.in_timeout?(user)
    |> call_if_miss(room, :in_timeout, user)
    |> call_if_miss(room, :get_user_timeouts, nil)
    |> return_timeout_result(room)
  end

  def get_timeouts(room) do
    call(room, :get_user_timeouts)
  end

  @doc """
  Get identifying process id for a room
  """
  def server_name(room_name) when is_binary(room_name), do: "ROOM_#{room_name}"

  # PRIVATE FUNCTIONS
  ###################
  defp call_if_miss(:cachemiss, room, action, args) do
    {:cachemiss, [call(room, action, args)]}
  end

  defp call_if_miss({:cachemiss, prev}, room, action, args) do
    {:cachemiss, [call(room, action, args)|prev]}
  end

  defp call_if_miss(result, _, _, _), do: result

  defp return_timeout_result({:cachemiss, [user_timeouts, in_timeout]}, room) do
    _ = QueryRoom.update_timeouts(room, user_timeouts)

    in_timeout
  end

  defp return_timeout_result(result, _), do: result

  defp call(%Room{} = room, :update_room) do
    case get_room_server_pid(room) do
      {:ok, pid} -> GenServer.call(pid, {:update_room, room})
      {:error, _} -> nil
    end
  end

  defp call(room, action, args \\ nil)

  defp call(%{name: name}, action, args), do: call(name, action, args)

  defp call(room_name, action, args) do
    case get_room_server_pid(room_name) do
      {:ok, pid} -> 
        GenServer.call(pid, {action, args})
      {:error, _error} -> 
        nil
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
          {:cachehit, room} -> RoomApp.add_child(%RoomState{room: room})
          {:ok, room} -> RoomApp.add_child(%RoomState{room: room})
          {:error, _} -> {:error, :room_not_found}
        end
      pid ->
        {:ok, pid}
    end
  end

  defp broadcast_if({:ok, _}, room, channel, %{} = event) do
    GabSub.broadcast(channel, event)
    room
  end

  defp broadcast_if(_, room, _, _), do: room

  defp broadcast_live(%Room{name: name} = room, %{} = event) do
    GabSub.broadcast("room_live:#{name}", event)
    room
  end
end