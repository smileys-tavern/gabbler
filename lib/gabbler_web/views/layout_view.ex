defmodule GabblerWeb.LayoutView do
  use GabblerWeb, :view

  def logo(), do: Application.get_env(:gabbler, :logo, "smileys")
end
