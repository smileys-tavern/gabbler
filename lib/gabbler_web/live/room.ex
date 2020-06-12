defmodule GabblerWeb.Live.Room do
  @moduledoc """
  A set of handles for incoming events related to generic room functionality. 
  Initializes data required for any liveview that involves a room (comments pages
  for example are within a room).
  """
  defmacro __using__(_) do
    quote do
      import Gabbler, only: [query: 1]
      import GabblerWeb.Gettext
      import Gabbler.Live.SocketUtil, only: [no_reply: 1, assign_to: 3, update_changeset: 5]

      alias Gabbler.Room, as: GabblerRoom
      alias Gabbler.Subscription, as: GabSub
      alias Gabbler.Type.Mode
      alias GabblerWeb.Presence

      @default_mode :hot

      @impl true
      def handle_info(%{event: "presence_diff"}, %{assigns: %{room: %{name: name}}} = socket) do
        Enum.count(Presence.list("room:#{name}"))
        |> assign_to(:user_count, socket)
        |> no_reply()
      end

      @impl true
      def handle_event("toggle_sidebar", _, %{assigns: %{sidebar_on: false}} = socket) do
        assign(socket, sidebar_on: true)
        |> no_reply()
      end

      @impl true
      def handle_event("toggle_sidebar", _, %{assigns: %{sidebar_on: true}} = socket) do
        assign(socket, sidebar_on: false)
        |> no_reply()
      end

      @impl true
      def handle_event("subscribe", _, %{assigns: %{user: user, room: room}} = socket) do
        assign_subscription(socket, query(:subscription).subscribe(user, room))
        |> broadcast_subscribed()
        |> no_reply()
      end

      @impl true
      def handle_event("unsubscribe", _, %{assigns: %{user: user, room: room}} = socket) do
        assign_unsubscribed(socket, query(:subscription).unsubscribe(user, room))
        |> broadcast_unsubscribed()
        |> no_reply()
      end

      @impl true
      def handle_event("submit_mod_invite", %{"mod" => %{"name" => name}}, %{assigns: %{room: room}} = socket) do
        invite_mod(socket, query(:user).get(name), room)
        |> no_reply()
      end

      @impl true
      def handle_event("remove_mod", %{"name" => user_name}, socket) do
        remove_mod(socket, query(:user).get(user_name))
        |> no_reply()
      end

      # PRIVATE FUNCTIONS
      ###################
      defp init(socket, %{"room" => _} = params, session) do
        assign_room(socket, params)
        |> assign_mode(params)
        |> init_room(:room_defaults)
        |> init_room(:presence)
        |> init_room(:mods)
        |> init_room(:subscription)
        |> init_room(:user_info)
        |> init_room(:room_owner)
        |> init(Map.drop(params, ["room"]), session)
      end

      defp assign_mode(socket, %{"mode" => mode}), do: socket
        |> assign(:mode, Mode.to_atom(mode))

      defp assign_mode(socket, _), do: assign(socket, :mode, @default_mode)

      defp assign_room(socket, %{"room" => name}), do: socket
        |> assign(:room, GabblerRoom.get_room(name))

      defp assign_room(socket, _), do: socket

      defp init_room(socket, :room_defaults) do
        assign(socket, 
          room_type: "room", 
          sidebar_on: false, 
          mod_invite: "", 
          user_count: 0)
      end

      defp init_room(%{assigns: %{room: nil}} = socket, _), do: socket

      defp init_room(%{assigns: %{room: room, user: nil, temp_token: tt}} = socket, :presence) do
        Presence.track(self(), "room:#{room.name}", tt, %{name: tt})

        assign(socket, user_count: Enum.count(Presence.list("room:#{room.name}")))
      end

      defp init_room(%{assigns: %{room: room, user: user}} = socket, :presence) do
        Presence.track(self(), "room:#{room.name}", user.id, %{name: user.name})

        assign(socket, user_count: Enum.count(Presence.list("room:#{room.name}")))
      end

      defp init_room(%{assigns: %{room: room}} = socket, :mods) do
        query(:moderating).list(room, join: :user)
        |> Enum.reduce([], fn {_, %{name: name}}, acc -> [name | acc] end)
        |> assign_to(:moderators, socket)
      end

      defp init_room(%{assigns: %{room: room, user: user}} = socket, :subscription) do
        query(:subscription).subscribed?(user, room)
        |> assign_to(:subscribed, socket)
      end

      defp init_room(%{assigns: %{room: room, user: user}} = socket, :user_info) do
        Gabbler.User.moderating?(user, room)
        |> assign_to(:mod, socket)
      end

      defp init_room(%{assigns: %{room: room}} = socket, :room_owner) do
        query(:user).get(room.user_id)
        |> assign_to(:owner, socket)
      end

      defp init_room(socket, _), do: socket

      defp assign_subscription(socket, {:ok, _subbed_result}) do
        assign(socket, subscribed: true)
      end

      defp assign_subscription(socket, {:error, _error}) do
        # TODO: handle notifying user
         assign(socket, subscribed: false)
      end

      defp assign_unsubscribed(socket, {:ok, _unsubbed_result}) do
        assign(socket, subscribed: false)
      end

      defp assign_unsubscribed(socket, {:error, _error}) do
        assign(socket, subscribed: true)
      end

      defp invite_mod(%{assigns: %{user: user}} = socket, nil, _) do
        Gabbler.User.notify(user, gettext("User not found so mod request could not be sent"), "warning")
        
        socket
      end

      defp invite_mod(%{assigns: %{user: user}} = socket, user_to_invite, %{name: room_name} = room) do
        _ = Gabbler.User.add_activity(user_to_invite, room_name, "mod_request")

        Gabbler.User.notify(user, gettext("Mod request sent"))

        assign(socket, mod_request: "")
      end

      defp remove_mod(socket, nil), do: no_reply(socket)

      defp remove_mod(%{assigns: %{room: room, moderators: mods}} = socket, %{name: user_name} = user) do
        _ = query(:moderating).remove_moderate(user, room)

        assign(socket, moderators: Enum.filter(mods, fn name -> name != user_name end))
      end

      defp broadcast_subscribed(%{assigns: %{user: user, room: room, subscribed: true}} = socket) do
        GabSub.broadcast("user:#{user.id}", %{event: "subscribed", room_name: room.name})

        socket
      end

      defp broadcast_subscribed(socket), do: socket

      defp broadcast_unsubscribed(%{assigns: %{user: user, room: room, subscribed: false}} = socket) do
        GabSub.broadcast("user:#{user.id}", %{event: "unsubscribed", room_name: room.name})

        socket
      end

      defp broadcast_unsubscribed(socket), do: socket
    end
  end
end
