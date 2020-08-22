defmodule Gabbler.PostCreation do
  @moduledoc """
  Helping functions for Creating a Post

  TODO: this module is being assimilated soon (into Post 'app')
  """
  import Gabbler
  import GabblerWeb.Gettext

  alias GabblerData.Room

  @doc """
  Handle post creation steps and reactions
  """
  def create(user, room, changeset, changeset_meta) do
    case Gabbler.User.can_post?(user) do
      true ->
        query(:post).create(prepare_changeset(room, changeset), changeset_meta)
        |> IO.inspect()

      false ->
        {:error,
         dgettext("errors", "post not created. You may have reached a daily posting limit.")}
    end
  end

  @doc """
  Prepare a Post Changeset for insertion to the database
  """
  def prepare_changeset(%Room{id: room_id} = room, changeset) do
    post_title = fetch_changeset_field(changeset, :title)

    Ecto.Changeset.change(changeset, %{hash: get_hash(post_title, room), room_id: room_id})
  end

  @doc """
  Retrieve a unique hash representing the post. If no Post title, downstream query
  will fail anyways so can empty string.
  """
  def get_hash(nil, _), do: ""

  def get_hash(title, %Room{id: room_id}) do
    {_, _, micro} = :os.timestamp()

    Hashids.new(salt: title <> room_id, min_len: 12)
    |> Hashids.encode([micro])
  end

  # PRIVATE FUNCTIONS
  ###################
  defp fetch_changeset_field(changeset, field, default \\ nil) do
    case Ecto.Changeset.fetch_field(changeset, field) do
      {:changes, value} -> value
      {:data, value} -> value
      _ -> default
    end
  end
end
