defmodule Gabbler.Subscription do
  @moduledoc """
  Alias for handling Gabbler PubSub subscriptions
  """
  alias Phoenix.PubSub

  def subscribe(channel_name) do 
    _ = PubSub.subscribe(Gabbler.PubSub, channel_name)
    channel_name
  end

  def unsubscribe(channel_name) do
    _ = PubSub.unsubscribe(Gabbler.PubSub, channel_name)
    channel_name
  end

  def broadcast(channel_name, payload), do: Gabbler.PubSub
    |> PubSub.broadcast(channel_name, payload)
end