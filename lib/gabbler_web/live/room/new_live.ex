defmodule GabblerWeb.Room.NewLive do
  @moduledoc """
  The Room Creation LiveView form
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: [:_page]
  import Gabbler.Live.SocketUtil, only: [no_reply: 1]

  alias Gabbler.Accounts.User
  alias Gabbler.Room, as: GabblerRoom
  alias GabblerData.{Room, Post, PostMeta}

  @doc """
  Set default form and status of creation
  """
  @impl true
  def mount(params, session, socket) do
    {:ok, init(socket, params, session)}
  end

  @doc """
  Handle a form update event where Room parameters were adjusted or the Room create/update form was submit
  """
  @impl true
  def handle_event("update_room", %{"_target" => target, "room" => room}, socket) do
    update_room_assign(target, room, socket)
    |> no_reply()
  end

  @impl true
  def handle_event("submit", _, %{assigns: %{changeset: changeset, mode: :create}} = socket) do
    update_room(socket, GabblerRoom.create_room(changeset))
    |> no_reply()
  end

  def handle_event("submit", _, %{assigns: %{changeset: changeset, mode: :update}} = socket) do
    update_room(socket, GabblerRoom.update_room(changeset))
    |> no_reply()
  end

  # PRIV
  #############################
  defp init(%{assigns: %{user: nil}} = socket, _, _) do
    socket
    |> put_flash(:info, gettext("Sign in to create a room"))
    |> redirect(to: "/")
  end

  defp init(%{assigns: assigns} = socket, %{"room" => name}, _) do
    case GabblerRoom.get_room(name) do
      nil ->
        assign(socket, default_assigns(assigns))

      room ->
        assign(socket,
          changeset: Room.changeset(room),
          room: room,
          status: nil,
          room_type: "room",
          posts: Post.mock_data(),
          post_metas: PostMeta.mock_data(),
          mode: :update,
          updated: false,
          users: %{1 => User.mock_data(), 2 => User.mock_data(), 3 => User.mock_data()}
        )
    end
  end

  defp init(%{assigns: assigns} = socket, _, _) do
    assign(socket, default_assigns(assigns))
  end

  defp update_room(socket, {:error, changeset}) do
    assign(socket, changeset: changeset)
  end

  defp update_room(socket, {:ok, room}) do
    socket
    |> assign(room: room, changeset: Room.changeset(room), mode: :update, updated: true)
    |> redirect(to: "/r/#{room.name}")
  end

  defp update_room_assign(["room", "title"], %{"title" => title}, socket) do
    update_room_assign(:title, title, socket)
  end

  defp update_room_assign(["room", "name"], %{"name" => name}, socket) do
    update_room_assign(:name, name, socket)
  end

  defp update_room_assign(["room", "description"], %{"description" => desc}, socket) do
    update_room_assign(:description, desc, socket)
  end

  defp update_room_assign(["room", "age"], %{"age" => age}, socket) do
    update_room_assign(:age, age, socket)
  end

  defp update_room_assign(["room", "type"], %{"type" => type}, socket) do
    update_room_assign(:type, type, socket)
  end

  defp update_room_assign(key, value, %{assigns: %{room: room, changeset: changeset}} = socket) do
    room = Map.put(room, key, value)

    assign(socket,
      room: room,
      changeset: update_changeset(changeset, key, value)
    )
  end

  defp update_room_assign(_, _, socket), do: socket

  defp update_changeset(changeset, key, value) do
    changeset =
      %{changeset | :errors => Keyword.delete(changeset.errors, key)}
      |> Room.changeset(%{key => value})

    case changeset do
      %{:errors => []} ->
        %{changeset | :valid? => true}
      _ -> 
        changeset
    end
  end

  defp default_assigns(%{user: %{id: user_id} = user}) do
    [
      changeset: Room.changeset(default_room(user)),
      room: %Room{type: "public", age: 0, user_id: user_id},
      status: nil,
      room_type: "room",
      posts: Post.mock_data(),
      post_metas: PostMeta.mock_data(),
      mode: :create,
      updated: false,
      user: user,
      users: %{1 => User.mock_data(), 2 => User.mock_data(), 3 => User.mock_data()}
    ]
  end

  defp default_room(%{id: user_id}),
    do: %Room{
      type: "public",
      age: 0,
      user_id: user_id,
      reputation: Application.get_env(:gabbler, :default_room_reputation, 0)
    }
end
