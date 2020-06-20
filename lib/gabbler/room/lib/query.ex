defmodule Gabbler.Room.Query do
  @moduledoc """
  The main querying interface for Room. Handles the relationship between cache and
  persistant store.
  """
  @behaviour GabblerData.Behaviour.QueryRoom

  import Gabbler, only: [query: 1]
  alias Gabbler.Cache
  alias GabblerData.Room
  alias GabblerData.Query.Room, as: QueryRoom

  @cache_default_ttl 86400 # 1 DAY

  def get(%Room{name: name}), do: get_by_name(name)

  @impl true
  def get(id), do: QueryRoom.get(id)

  @impl true
  def get_by_name(name) do
    case Cache.get("ROOM_#{name}") do
      nil ->
        query(:room).get_by_name(name)
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

  defp room_found?(nil), do: {:error, :room_not_found}
  defp room_found?(room), do: {:ok, room}
end