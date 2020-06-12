defmodule Gabbler.Room.PostDecay do
  @moduledoc """
  This module provides some abstraction to decay a posts relevance by time

  TODO: move decay settings to configuration
  """
  import Gabbler, only: [query: 1]
  alias GabblerData.Room

  @default_decay_ratio 0.85


  @doc """
  Get the atom version of an expirey mode
  """
  def decay("rapid"), do: :rapid
  def decay("slow"), do: :slow
  def decay("never"), do: :never

  @doc """
  Get the amount of time until decay (milliseconds)
  """
  def set_decay_timer(:rapid) do
    # Each 1 hour
    Process.send_after(self(), :decay, 3600000)
    :ok
  end

  def set_decay_timer(:slow) do
    # Each 4 hours
    Process.send_after(self(), :decay, 144000000)
    :ok
  end

  def set_decay_timer(_), do: nil

  @doc """
  Decay posts on behalf of a room. If posts fall within the 'decay period' their private
  score will be reduced quickly. Returns :ok or :error tuple with amount of posts affected
  """
  def decay_room_posts(%Room{} = room) do
    query(:post).multiply_scores(room, @default_decay_ratio, 24, 28)
  end
end