defmodule Gabbler.Subscription do
  @moduledoc """
  Alias for handling Gabbler PubSub subscriptions
  """
  alias Phoenix.PubSub

  def subscribe(channel_name), do: PubSub.subscribe(Gabbler.PubSub, channel_name)
  def unsubscribe(channel_name), do: PubSub.unsubscribe(Gabbler.PubSub, channel_name)
  def broadcast(channel_name, payload), do: Gabbler.PubSub
    |> PubSub.broadcast(channel_name, payload)
end