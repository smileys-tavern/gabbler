defmodule Gabbler.User do
  @moduledoc """
  Each user has their own server storing actions in memory which helps keep timers
  on whether they can post (spam prevention) and whether they already voted on a 
  post. Also keeps their subscriptions and moderator list cached.

  This module also handles events as procedures of related state changes. It ensures
  when a user's state changes it chains into broadcasting change results.
  """
  import Gabbler.Guards, only: [alert?: 1, user_event?: 1]
  import GabblerWeb.Gettext

  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.Accounts.User
  alias Gabbler.User.Application, as: UserApp
  alias Gabbler.User.QuerySubscription, as: QuerySub
  alias Gabbler.User.QueryModerating, as: QueryMod
  alias Gabbler.User.Query, as: QueryUser

  @max_moderating 7
  @max_subscriptions 7

  @doc """
  Methods to manage user state / persistant data
  """
  def get_by_name(name) do
    case QueryUser.get_by_name(name) do
      {:cachehit, user} -> user
      {:ok, user} -> call(user, :update_user, user)
      {:error, _} -> nil
    end
  end

  def subscribe(user, %{name: name} = room) do
    user
    |> QuerySub.subscribe(room)
    |> call_if(user, :activity_subscribed, room)
    |> broadcast_if(user, %{event: "subscribed", room_name: name})
  end

  def unsubscribe(user, room) do
    user
    |> QuerySub.unsubscribe(room)
    |> call_if(user, :activity_unsubscribed, room)
  end

  def add_mod(user, room) do
    user
    |> QueryMod.moderate(room)
    |> call_if(user, :activity_moderating, room)
    |> broadcast_if(user, {:modding_room, :modding_room_error})
  end

  def remove_mod(user, room) do
    user
    |> QueryMod.remove_moderate(room)
    |> call_if(user, :activity_moderate_remove, room)
  end

  def invite_to_mod(nil, from_user, _), do: {:error, notify(from_user, :mod_request_failed)}

  def invite_to_mod(user, from_user, %{name: name}) do
    _ = call(user, :add_activity, {name, "mod_request"})
    
    {:ok, notify(from_user, :mod_request_sent)}
  end

  @doc """
  Retrieve all info for a user
  """
  def all(user) do
    call(user, :retrieve_all)
  end

  @doc """
  User voted
  """
  def activity_voted(user, post_hash) do
    call(user, :activity_voted, post_hash)
  end

  @doc """
  User posted
  """
  def activity_posted(user, post_hash) do
    call(user, :activity_posted, post_hash)
  end

  @doc """
  Add a simple activity to a fixed length FILO queue. Should expect the value to be displayed
  organized by the id key
  """
  def add_activity(user, id, value) do
    call(user, :add_activity, {id, value})
  end

  @doc """
  Remove a single activity key
  """
  def remove_activity(user, id) do
    call(user, :remove_activity, id)
  end

  @doc """
  Update the read receipt status, indicating there are unread notices
  """
  def update_read_receipt(user, read) when read in [true, false] do
    cast(user, :update_read_receipt, read)
  end

  @doc """
  Returns whether a user can currently post
  """
  def can_vote?(user, post_hash) do
    call(user, :can_vote, post_hash)
  end

  @doc """
  Returns whether a user can currently post
  """
  def can_post?(user) do
    call(user, :can_post)
  end

  @doc """
  Return the map of responses to users activity. Mapped post hashes to tuple with room name
  """
  def get_activity(user) do
    call(user, :get_activity)
  end

  @doc """
  Return hashes of all a users recent posts
  """
  def posts(user) do
    call(user, :get_posts)
  end

  @doc """
  Return the list of this users subscription room names
  """
  def subscriptions(user) do
    call(user, :get_subscriptions)
  end

  @doc """
  Return the map of rooms moderating, a list of moderated room names.
  """
  def moderating(user) do
    call(user, :get_moderating)
  end

  @doc """
  Return whether a user is the mod of a room
  """
  def moderating?(user, room) do
    call(user, :moderating, room)
  end

  @doc """
  Generic broadcast support (possibly temporary)
  """
  def broadcast(%User{id: id}, msg, type \\ "info") do
    GabSub.broadcast("user:#{id}", %{event: type, msg: msg})
  end

  @doc """
  Create a server name based on a user so it can be found easily by id
  """
  def server_name(%User{id: id}), do: "USER_SERV_#{id}"

  # PRIVATE FUNCTIONS
  ###################
  defp call_if({:ok, _}, user, action, args), do: {:ok, call(user, action, args)}
  defp call_if({:error, _}, user, action, args), do: {:error, notify(user, :error, action, args)}
  defp call_if(_, user, action, args), do: {:error, notify(user, :error, action, args)}

  def broadcast_if({:ok, user}, {action, _}), do: {:ok, notify(user, action)}
  def broadcast_if({:error, user}, {_, action}), do: {:error, notify(user, action)}
  def broadcast_if({:ok, _}, user, event), do: {:ok, broadcast_msg(user, event)}
  def broadcast_if({:error, _}, user, _), do: {:error, user}

  defp call(user, action, args \\ [])

  defp call(nil, _, _), do: nil

  defp call(user_id, action, args) when is_binary(user_id) do
    call(QueryUser.get(user_id), action, args)
  end

  defp call(%User{} = user, action, args) do
    pid = get_user_server_pid(user)

    case args do
      [] -> GenServer.call(pid, action)
      _ -> GenServer.call(pid, {action, args})
    end
  end

  defp cast(%User{} = user, action, args) do
    pid = get_user_server_pid(user)

    case args do
      [] -> GenServer.cast(pid, action)
      _ -> GenServer.cast(pid, {action, args})
    end
  end

  defp get_user_server_pid(user) do
    case :syn.whereis(server_name(user)) do
      :undefined ->
        subs = user
        |> QuerySub.list(join: :room, limit: @max_subscriptions)
        |> Enum.reduce([], fn {_, %{name: name}}, acc -> [name | acc] end)

        moderating = user
        |> QueryMod.list(join: :room, limit: @max_moderating)
        |> Enum.reduce([], fn {_, %{name: name}}, acc -> [name | acc] end)

        case UserApp.add_child(user, subs, moderating) do
          {:error, {:already_started, pid}} -> pid
          {:ok, pid} -> pid
        end

      pid ->
        pid
    end
  end

  defp notify(user, :mod_request_sent), do: user
  |> broadcast_msg(gettext("Mod request sent"), "info")

  defp notify(user, :mod_request_failed), do: user
  |> broadcast_msg(gettext("User not found so mod request could not be sent"), "warning")

  defp notify(user, :modding_room), do: user
  |> broadcast_msg(gettext("Added as moderator"), "info")

  defp notify(user, :modding_room_error), do: user
  |> broadcast_msg(gettext("Failed to add as moderator"), "warning")

  defp notify(user, :error, :invite_mod, {nil, _}), do: user
  |> broadcast_msg(gettext("User not found so mod request could not be sent"), "warning")

  defp broadcast_msg(%{id: id} = user, %{event: event_name} = event) when user_event?(event_name) do
    GabSub.broadcast("user:#{id}", event)
    user
  end

  defp broadcast_msg(%{id: id} = user, msg, type) when alert?(type) do
    GabSub.broadcast("user:#{id}", %{event: type, msg: msg})
    user
  end
end
