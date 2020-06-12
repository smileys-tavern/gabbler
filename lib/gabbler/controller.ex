defmodule Gabbler.Controller do
  @moduledoc """
  The gabbler controller includes functions to extend the functionality of web controllers.
  Used similar to a plug but mainly standardizes some common usages of parameters.

  NOTE: now that params are passed to liveview modules by default. Much of this could be
  considered for refactor, cleaning it up while moving to liveview helpers
  """
  use GabblerWeb, :controller
  import Gabbler, only: [query: 1]
  import Plug.Conn, only: [assign: 3, put_status: 2]

  alias Gabbler.Room, as: GabblerRoom
  alias Gabbler.Type.Mode

  @default_mode :hot

  @doc """
  Add a room to a session map if possible
  """
  def add_room(conn, %{"room" => name}), do: conn
    |> assign(:room, GabblerRoom.get_room(name))

  def add_room(conn, _), do: conn

  @doc """
  Add a post to a session map if possible, including the focus information when a comment is
  being viewed of an original content post
  """
  def add_post(conn, %{"hash" => hash, "focushash" => focus_hash}), do: conn
    |> assign(:post, query(:post).get(focus_hash))
    |> assign(:op, query(:post).get(hash))
    |> assign(:focus_hash, focus_hash)
  
  def add_post(conn, %{"hash" => hash}), do: conn
    |> assign(:post, query(:post).get(hash))
    |> assign(:focus_hash, nil)

  def add_post(conn, _), do: conn

  @doc """
  Add the mode to the session or a default
  """
  def add_mode(conn, %{mode: mode}), do: assign(conn, :mode, Mode.to_atom(mode))
  def add_mode(conn, _), do: assign(conn, :mode, @default_mode)

  @doc """
  Add a user to the connection
  """
  def assign_user(conn, %{"username" => name}), do: conn
    |> assign(:subject_user, query(:user).get(URI.decode(name)))
  
  def assign_user(conn, _), do: conn

  @doc """
  Add a parameter to the connection using the passed function
  """
  def assign_to(conn, key, value_fn), do: conn
    |> assign(key, value_fn.(conn))

  @doc """
  Add a parameter to the session using the passed function
  """
  def add_session_param(session, key, value_fn), do: session
    |> Map.put(key, value_fn.(session))

  @doc """
  Render using a given rendering function if conditions are met.
  Conditions are that the given keys exist and are not nil in the session
  """
  def render_if(%{assigns: assigns} = conn, keys, render_fn) do
    if Enum.all?(keys, &Map.has_key?(assigns, &1)) do
      render_fn.(conn)
    else
      render_404(conn)
    end
  end

  def render_404(conn) do
    conn
    |> put_status(:not_found)
    |> render(GabblerWeb.ErrorView, "404.html")
  end
end