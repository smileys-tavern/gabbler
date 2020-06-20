defmodule Gabbler.User.QuerySubscription do
  @moduledoc """
  The main querying interface for a User Account. Handles the relationship between cache and
  persistant store.
  """
  @behaviour GabblerData.Behaviour.QuerySubscription

  alias GabblerData.Query.Subscription, as: QuerySub


  @impl true
  def subscribe(user, room), do: QuerySub.subscribe(user, room)

  @impl true
  def unsubscribe(user, room), do: QuerySub.unsubscribe(user, room)

  @impl true
  def subscribed?(user, room), do: QuerySub.subscribed?(user, room)

  @impl true
  def list(user, opts), do: QuerySub.list(user, opts)
end