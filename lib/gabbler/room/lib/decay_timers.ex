defmodule Gabbler.Room.DecayTimers do
  @moduledoc """
  This module provides some abstraction to decay posts / users relevance by time

  TODO: move decay settings to configuration
  """
  alias GabblerData.Room

  #@default_decay_ratio 0.85


  @doc """
  Set a fast timer
  """
  def set_decay_timer(key, time) do
    # Each 1 hour
    self()
    |> Process.send_after(key, time)
    :ok
  end

  @doc """
  Decay posts on behalf of a room. If posts fall within the 'decay period' their private
  score will be reduced quickly. Returns :ok or :error tuple with amount of posts affected
  """
  def decay_room_posts(%Room{} = _room) do
    :ok
    #TODO: investigate
    #query(:post).multiply_scores(room, @default_decay_ratio, 24, 28)
  end
end