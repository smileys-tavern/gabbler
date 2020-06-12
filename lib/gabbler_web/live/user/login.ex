defmodule GabblerWeb.Live.User.Login do
  @moduledoc """
  Authentication live view to manage the ui based on a users status and actions

  NOTE: Partially abandoning the liveview login screen in favor of a simple
  login landing page for a while.
  """
  use Phoenix.LiveView
  import Gabbler.Live.SocketUtil, only: [no_reply: 1, update_changeset: 5]

  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.Accounts.User

  def render(assigns) do
    ~L"""
      <%= Phoenix.View.render(GabblerWeb.UserView, "login.html", assigns) %>
    """
  end

  @doc """
  Set default form and status of creation
  """
  def mount(_params, session, socket) do
    {:ok, init(session, socket)}
  end

  def handle_info(%{event: "login_show"}, socket) do
    assign(socket, show_auth: true)
    |> no_reply()
  end

  def handle_event("login_show", _, socket), do: no_reply(assign(socket, show_auth: true))
  def handle_event("login_hide", _, socket), do: no_reply(assign(socket, show_auth: false))

  def handle_event("login_mode", %{"mode" => "login"}, socket) do
    assign(socket, mode: :login)
    |> no_reply()
  end

  def handle_event("login_mode", %{"mode" => "register"}, socket) do
    assign(socket, mode: :register)
    |> no_reply()
  end

  def handle_event("login_mode", %{"mode" => "logout"}, socket) do
    assign(socket, mode: :logout)
    |> no_reply()
  end

  def handle_event("login_change", %{"_target" => target, "user" => user}, socket) do
    update_user_changeset(socket, target, user)
    |> no_reply()
  end

  # PRIV
  #############################
  defp init(session, socket) do
    assign_user_info(socket, session)
    |> assign_defaults()
  end

  def assign_user_info(socket, %{"user" => %User{} = user, "csrf" => csrf}) do
    assign(socket, 
      user: user,
      mode: :logout,
      csrf: csrf)
  end

  def assign_user_info(socket, %{"temp_token" => temp_token, "csrf" => csrf}) do
    GabSub.subscribe("user:#{temp_token}")

    assign(socket, 
      user: %User{},
      mode: :login,
      csrf: csrf)
  end

  def assign_defaults(%{assigns: %{user: user}} = socket) do
    assign(socket,
      changeset_user: User.changeset(user),
      show_auth: false)
  end

  defp update_user_changeset(socket, ["user", "name"], %{"name" => name}) do
    update_changeset(socket, :changeset_user, :user, :name, name)
  end

  defp update_user_changeset(socket, ["user", "password"], %{"password" => password}) do
    update_changeset(socket, :changeset_user, :user, :password, password)
  end

  defp update_user_changeset(socket, ["user", "email"], %{"email" => email}) do
    update_changeset(socket, :changeset_user, :user, :email, email)
  end

  defp update_user_changeset(socket, _, _), do: socket
end
