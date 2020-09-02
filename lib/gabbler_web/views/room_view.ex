defmodule GabblerWeb.RoomView do
  use GabblerWeb, :view

  def show_error(nil), do: ""

  def show_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  def post_link(%{name: name}, %{parent_type: "room", hash: hash, title: title}, _) do
    "/r/#{name}/comments/#{hash}/#{String.replace(title, "#", "")}"
  end

  def post_link(%{name: name}, %{hash: hash}, %{hash: op_hash}) do
    "/r/#{name}/comments/#{op_hash}/focus/#{hash}"
  end

  def post_link(_room, _post, _op), do: "#"
end
