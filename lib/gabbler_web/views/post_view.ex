defmodule GabblerWeb.PostView do
  use GabblerWeb, :view

  def posted_at(nil), do: "at unknown time"

  def posted_at(datetime) do
    Timex.format!(datetime, "{relative}", :relative)
  end

  def display_post_body(%{body: body}) do
    Earmark.as_html!(body)
    |> String.replace("\r", "<br/>")
  end

  def get_post_body(changeset) do
    case Ecto.Changeset.fetch_field(changeset, :body) do
      {:changes, body} -> body
      {:data, body} -> body
      _ -> ""
    end
  end
end
