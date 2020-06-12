defmodule Gabbler do
  @moduledoc """
  The Gabbler context that provides access to configured modules that handle some of the core
  data querying and logic patterns to help the site operate.
  """

  @doc """
  Wraps any attempt to call the data module
  """
  def query(module),
    do:
      Application.get_env(:gabbler, :query, GabblerData.Query)
      |> Module.concat(to_module(module))

  # PRIVATE FUNCTIONS
  ###################
  defp to_module(:post), do: :Post
  defp to_module(:room), do: :Room
  defp to_module(:user), do: :User
  defp to_module(:moderating), do: :Moderating
  defp to_module(:subscription), do: :Subscription
end
