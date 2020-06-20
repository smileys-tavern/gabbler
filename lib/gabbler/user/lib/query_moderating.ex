defmodule Gabbler.User.QueryModerating do
  @moduledoc """
  The main querying interface for User data related to moderating rooms
  """
  @behaviour GabblerData.Behaviour.QueryModerating

  alias GabblerData.Room
  alias GabblerData.Query.Moderating, as: QueryModerating


  @impl true
  def moderate(user, room), do: QueryModerating.moderate(user, room)

  @impl true
  def remove_moderate(user, room), do: QueryModerating.remove_moderate(user, room)

  @impl true
  def moderating?(user, room), do: QueryModerating.moderating?(user, room)

  @impl true
  def list(%Room{} = room, opts), do: QueryModerating.list(room, opts)

  @impl true
  def list(user, opts), do: QueryModerating.list(user, opts)
end