defmodule GabblerWeb.LayoutView do
  use GabblerWeb, :view

  def logo(), do: Application.get_env(:gabbler, :logo, "smileys")

  def title(_), do: Application.get_env(:gabbler, :page_desc, "Build Your Community")
end
