defmodule Gabbler.Room.Query do
  @moduledoc """
  The main querying interface for Room. Handles the relationship between cache and
  persistant store.
  """
  @behaviour GabblerData.Behaviour.QueryRoom

  alias Gabbler.Cache
  alias GabblerData.Room
  alias GabblerData.Query.Room, as: QueryRoom

  @cache_default_ttl 86400 # 1 DAY
  @cache_ban_ttl 3600 # 1 HOUR

  def get(%Room{name: name}), do: get_by_name(name)

  @impl true
  def get(id), do: QueryRoom.get(id)

  @impl true
  def get_by_name(name) do
    case Cache.get("ROOM_#{name}") do
      nil ->
        QueryRoom.get_by_name(name)
        |> Cache.set_if("ROOM_#{name}", ttl: @cache_default_ttl)
        |> room_found?()
      room ->
        {:cachehit, room}
    end
  end

  @impl true
  def list(_), do: []

  @impl true
  def increment_reputation(_, _), do: {:ok, %Room{}}

  @impl true
  def create(changeset), do: QueryRoom.create(changeset)

  @impl true
  def update(_changeset) do
    #get_by_name(changeset.data.name)
    #|> Map.merge(changeset.data)
    #|> QueryRoom.update()

    {:ok, nil}#Cache.update()}
  end

  def update_timeouts(%{name: name} = room, %{} = user_timeouts) do
    _ = Cache.set("ROOM_UTO_#{name}", user_timeouts, ttl: @cache_default_ttl)
    room
  end

  def reset_timeouts(%{name: name}), do: Cache.delete("ROOM_UTO_#{name}")

  def in_timeout?(%{name: name}, %{name: user_name}) do
    case Cache.get("ROOM_UTO_#{name}") do
      nil -> 
        :cachemiss
      user_timeouts -> 
        Map.has_key?(user_timeouts, user_name)
    end
  end

  # Ban functions!
  @impl true
  def ban_for_life(id, user_id) do
    QueryRoom.ban_for_life(id, user_id)
  end

  @impl true
  def unban(id, user_id) do
    QueryRoom.unban(id, user_id)
  end

  @impl true
  def banned?(id, user_id) do
    case Cache.get("BAN_#{user_id}_#{id}") do
      nil -> 
        QueryRoom.banned?(id, user_id)
        |> Cache.set_if("BAN_#{user_id}_#{id}", ttl: @cache_ban_ttl)
        |> banned?()
      banned ->
        banned
    end
  end

  # PRIVATE FUNCTIONS
  ###################
  defp room_found?(nil), do: {:error, :room_not_found}
  defp room_found?(room), do: {:ok, room}

  defp banned?(false), do: false
  defp banned?({:ok, true}), do: true
end