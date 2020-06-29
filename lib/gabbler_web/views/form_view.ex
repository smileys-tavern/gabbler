defmodule GabblerWeb.FormView do
  use GabblerWeb, :view

  def show_error(nil), do: ""

  def show_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      case value do
        list when is_list(list) -> 
          String.replace(acc, "%{#{key}}", to_string(Enum.join(list, " ")))
        _ -> 
          String.replace(acc, "%{#{key}}", to_string(value))
      end
    end)
  end

  def capitalize_all(string) do
    Enum.join(Enum.map(String.split(string, "_"), &String.capitalize(&1)), " ")
  end
end
