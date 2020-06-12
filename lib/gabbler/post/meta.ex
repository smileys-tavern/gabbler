defmodule Gabbler.Post.Meta do
  @moduledoc """
  Logic related to a posts meta data: image, tags, link, comment count
  """
  @behaviour GabblerData.Behaviour.LogicMeta

  alias GabblerData.PostMeta

  @impl true
  def upload_image(_image_data, _tags), do: :ok

  @impl true
  def process_tags(%PostMeta{} = meta, tags) when is_list(tags) do
    process_tags(meta, Enum.slice(tags, 0..Application.get_env(:gabbler, :post_max_tags, 3)), [])
  end

  @impl true
  def process_tags(meta, tags), do: process_tags(meta, String.split(tags, ",", trim: true))

  @impl true
  def format_tags(tags), do: String.split(tags, ",", trim: true) |> Enum.join(", ")

  @impl true
  def filter_tags(tags) when is_list(tags) do
    Enum.slice(tags, 0..Application.get_env(:gabbler, :post_max_tags, 3))
    |> Enum.filter(fn tag -> String.length(tag) > 2 end)
  end

  @impl true
  def filter_tags(nil), do: []

  def filter_tags(tags) do
    String.split(tags, ",", trim: true)
    |> filter_tags()
  end

  defp process_tags(_meta, [], acc), do: acc

  defp process_tags(%PostMeta{:link => link} = meta, ["youtube" | t], acc) do
    url =
      URI.parse(link)
      |> Map.get(:query)
      |> URI.decode_query()

    html =
      Phoenix.View.render_to_string(GabblerWeb.EmbedView, "youtube.html", %{:hash => url["v"]})

    process_tags(meta, t, [{:html, html} | acc])
  end

  defp process_tags(%PostMeta{:link => link} = meta, ["bingmap" | t], acc) do
    url =
      URI.parse(link)
      |> Map.get(:query)
      |> URI.decode_query()

    cond do
      url["cp"] ->
        html =
          Phoenix.View.render_to_string(GabblerWeb.EmbedView, "bing_map.html", %{
            :coord => url["cp"],
            :position => String.replace(url["cp"], "~", "_")
          })

        process_tags(meta, t, [{:html, html} | acc])

      true ->
        process_tags(meta, t, acc)
    end
  end

  defp process_tags(meta, [_ | t], acc), do: process_tags(meta, t, acc)
end
