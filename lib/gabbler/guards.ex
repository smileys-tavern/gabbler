defmodule Gabbler.Guards do
  @moduledoc """
  Custom guard classes generic to Gabbler
  """
  defguard alert?(value) when value in ["info", "warning", "error"]

  defguard user_event?(value) when value in ["subscribed"]

  defguard private?(room_type) when room_type in ["private"]

  defguard restricted?(room_type) when room_type in ["restricted", "private"]
end