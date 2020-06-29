defmodule Gabbler.Room.Server do
  use GenServer

  alias GabblerData.Room
  alias Gabbler.Room.{RoomState, DecayTimers}
  alias Gabbler.Room.Query, as: QueryRoom

  # Timeout after 96 hours inactivity
  @server_timeout 1000 * 60 * 60 * 96


  def start_link(%RoomState{room: %{name: room_name}} = room_state) do
    GenServer.start_link(
      __MODULE__, room_state, name: {:via, :syn, Gabbler.Room.server_name(room_name)}, timeout: @server_timeout
    )
  end

  @impl true
  def init(%RoomState{decay_mode: mode} = room_state) do
    _ = DecayTimers.set_decay_timer(:decay, to_seconds(mode))

    {:ok, room_state}
  end

  @impl true
  def handle_call({:get_room, _}, _from, %RoomState{room: room} = state) do
    {:reply, room, state}
  end

  @impl true
  def handle_call({:update_room, %Room{} = room}, _from, %RoomState{} = state) do
    {:reply, room, %{state | room: room}}
  end

  @impl true
  def handle_call({:get_user_timeouts, _}, _from, %RoomState{user_timeout: users} = state) do
    {:reply, users, state}
  end

  @impl true
  def handle_call({:in_timeout, %{name: user_name}}, _from, %RoomState{user_timeout: users} = state) do
    {:reply, Map.has_key?(users, user_name), state}
  end

  @impl true
  def handle_call({:user_timeout, {%{name: user_name}, hash}}, _from, %RoomState{user_timeout: users} = state) do
    _ = DecayTimers.set_decay_timer(:end_timeout, to_seconds(:user_timeout))

    users = Map.put(users, user_name, hash)

    {:reply, users, %{state | user_timeout: users}}
  end

  @impl true
  def handle_info(:decay, %RoomState{room: room, decay_mode: mode} = state) do
    _ = DecayTimers.set_decay_timer(:decay, to_seconds(mode))

    _ = DecayTimers.decay_room_posts(room)

    {:noreply, state}
  end

  def handle_info({:end_timeout, %{id: user_id}}, %RoomState{room: room, user_timeout: users} = state) do
    _ = QueryRoom.reset_timeouts(room)

    {:noreply, %{state | user_timeout: Map.drop(users, [user_id])}}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
  defp to_seconds(:rapid), do: 3600000
  defp to_seconds(:slow), do: 144000000
  defp to_seconds(:user_timeout), do: 144000000
end
