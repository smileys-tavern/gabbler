defmodule Gabbler.Room do
  @moduledoc """
  Each room has it's own server responsible for decaying it's posts and deactivating if the room loses activity
  for long enough. Rooms that aren't used in a long while have their servers expire.

  The fast access app cache is used when possible, falling back to the database. Any time
  the database is used the Room Server has it's room info refreshed.
  """
  import GabblerWeb.Gettext
  import Gabbler.Guards, only: [restricted?: 1]
  import Gabbler, only: [query: 1]

  alias Gabbler.Room.Application, as: RoomApp
  alias Gabbler.Room.Query, as: QueryRoom
  alias Gabbler.Post.Query, as: QueryPost
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
  Retrieve a rooms latest posts
  """
  def latest_posts(%{id: id}) do
    QueryPost.list(by_room: id, order_by: :inserted_at, limit: 5)
  end

  @doc """
  Retrieve the newest rooms
  """
  def newest_rooms(limit \\ 5) do
    QueryRoom.list(limit: limit, order_by: :recent)
  end

  @doc """
  Create a room using data store
  """
  def create_room(changeset), do: QueryRoom.create(changeset)

  @doc """
  Update a room using data store
  """
  def update_room(changeset), do: QueryRoom.update(changeset)

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

  @doc """
  Ban a user (for life)
  """
  def user_ban(_, nil), do: {:error, :user_not_found}

  def user_ban(%{id: id, name: name} = room, %{id: user_id}) do
    # TODO: formalize channels in protocol so they aren't ad-hoc string codes
    QueryRoom.ban_for_life(id, user_id)
    |> broadcast_if(room, "user:#{user_id}", %{event: "banned_for_life", room_name: name})
  end

  @doc """
  Unban a user (not as for life as thought!)
  """
  def user_unban(_, nil), do: {:error, :user_not_found}

  def user_unban(%{id: id, name: name} = room, %{id: user_id}) do
    QueryRoom.unban(id, user_id)
    |> broadcast_if(room, "user:#{user_id}", %{event: "unbanned", room_name: name})
  end

  @doc """
  Is the user currently banned
  """
  def banned?(_, nil), do: false

  def banned?(%{id: id}, %{id: user_id}), do: QueryRoom.banned?(id, user_id)

  @doc """
  Return boolean based on whether a user is allowed in the room
  """
  def allow_entrance?(nil, _), do: true

  def allow_entrance?(%{type: "private"}, nil), do: false

  def allow_entrance?(room, user) do
    banned?(room, user)
    |> allow_private_if_not_banned?(room, user)
  end

  @doc """
  Return true/false based on if the user is in a timeout currently. Handles
  refreshing the cache if cache not found. Timeouts source of truth is the
  rooms server
  """
  def in_timeout?(room, user) do
    room
    |> QueryRoom.in_timeout?(user)
    |> call_if_miss(room, :in_timeout, user)
    |> call_if_miss(room, :get_user_timeouts, nil)
    |> return_timeout_result(room)
  end

  @doc """
  Retrieve info about the moderators for a room
  """
  def moderators(room), do: query(:moderating).list(room, join: :user)

  @doc """
  True/False whether a user is subbed
  """
  def subscribed?(room, user), do: query(:subscription).subscribed?(user, room)

  @doc """
  Retrieve all current users in timeouts for this room
  """
  def get_timeouts(room) do
    call(room, :get_user_timeouts)
  end

  @doc """
  Allow/Disallow a user to a private room (no-op on non-private room)
  """
  def allow_user(_, nil), do: {:error, :user_not_found}

  def allow_user(%{id: id, type: "private"}, %{id: user_id}) do
    QueryRoom.add_to_allow_list(id, user_id)
  end

  def allow_user(room, _), do: {:error, room}

  def disallow_user(_, nil), do: {:error, :user_not_found}

  def disallow_user(%{id: id, type: "private"}, %{id: user_id}) do
    QueryRoom.remove_from_allow_list(id, user_id)
  end

  def disallow_user(room, _), do: {:error, room}

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

  defp allow_private_if_not_banned?(true, _, _), do: false

  defp allow_private_if_not_banned?(_, %{user_id: creator_id}, %{id: creator_id}), do: true

  defp allow_private_if_not_banned?(false, %{id: id, type: type}, %{id: user_id}) when restricted?(type) do
    QueryRoom.allow_list?(id, user_id)
  end

  defp allow_private_if_not_banned?(false, _, _), do: true

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