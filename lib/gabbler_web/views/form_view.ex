defmodule GabblerWeb.FormView do
  use GabblerWeb, :view

  def show_error(nil), do: ""

  def show_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  def capitalize_all(string) do
    Enum.join(Enum.map(String.split(string, "_"), &String.capitalize(&1)), " ")
  end
end
