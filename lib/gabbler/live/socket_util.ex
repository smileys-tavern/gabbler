defmodule Gabbler.Live.SocketUtil do
  @moduledoc """
  All functions here should accept a socket and return a socket. Meant for common functionality related
  to forms and liveviews. This module is best used via import

  TODO: update module purpose, make it about changesets instead of the socket conn
  """
  import Phoenix.LiveView

  alias GabblerData.{Room, Post, PostMeta, Comment}
  alias Gabbler.Accounts.User

  @doc """
  Alias for :noreply on sockets to assist with piping code-flows
  """
  def no_reply(socket), do: {:noreply, socket}

  @doc """
  Alias for assign as a convenience to pipe data into the socket
  """
  def assign_to(value, key, socket), do: assign(socket, [{key, value}])

  @doc """
  Update a changeset in a way standard to many of gabbler's liveview forms
  """
  def update_changeset(%{assigns: assigns} = socket, changeset_name, type, key, value) do
    changeset = Map.get(assigns, changeset_name)
    updated_struct = Map.get(assigns, type) |> Map.put(key, value)

    assign(socket, [
      {type, updated_struct},
      {changeset_name, update_changeset_val(changeset, type, key, value)}
    ])
  end

  # PRIVATE FUNCTIONS
  ###################
  defp update_changeset_val(changeset, type, key, value) do
    changeset =
      %{changeset | :errors => Keyword.delete(changeset.errors, key)}
      |> changeset_model(type).changeset(%{key => value})

    case changeset do
      %{:errors => []} -> %{changeset | :valid? => true}
      _ -> changeset
    end
  end

  defp changeset_model(:comment), do: Comment
  defp changeset_model(:reply), do: Comment
  defp changeset_model(:room), do: Room
  defp changeset_model(:post), do: Post
  defp changeset_model(:post_meta), do: PostMeta
  defp changeset_model(:user), do: User
end
