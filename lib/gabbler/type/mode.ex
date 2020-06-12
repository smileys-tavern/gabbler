defmodule Gabbler.Type.Mode do
  @moduledoc """
  A mode is a modifier on a room, post, etc dictating how it's viewed and used
  """

  @doc """
  Convert to atom
  """
  def to_atom("hot"), do: :hot
  def to_atom("new"), do: :new
  def to_atom("live"), do: :live
  def to_atom(_), do: nil
end