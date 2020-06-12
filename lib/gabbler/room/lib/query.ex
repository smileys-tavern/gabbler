defmodule Gabbler.Room.Query do
  @moduledoc """
  The main querying interface for Room. Uses only the caching/memory layer

  TODO: validation and handling of more situations (cache miss on update for example)
  """
  @behaviour GabblerData.Behaviour.QueryRoom

  alias Gabbler.Cache
  alias GabblerData.Room

  def get(%Room{name: name}), do: get_by_name(name)

  @impl true
  def get(id), do: Room.get(id)

  @impl true
  def get_by_name(name), do: Cache.get("ROOM_#{name}")

  @impl true
  def list(_), do: []

  @impl true
  def increment_reputation(_, _), do: {:ok, %Room{}}

  @impl true
  def create(changeset) do
    room = changeset.data

    {:ok, Cache.set(room.name, room)}
  end

  @impl true
  def update(changeset) do
    _room = get(changeset.data.name)
    |> Map.merge(changeset.data)

    {:ok, nil}#Cache.update()}
  end
end