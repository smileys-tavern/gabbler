defmodule Gabbler.Room.Server do
  use GenServer

  alias GabblerData.Room
  alias Gabbler.Room.{RoomState, PostDecay}

  # Timeout after 96 hours inactivity
  @server_timeout 1000 * 60 * 60 * 96


  def start_link(%RoomState{room: %{name: room_name}} = room_state) do
    GenServer.start_link(
      __MODULE__, room_state, name: Gabbler.Room.server_name(room_name), timeout: @server_timeout
    )
  end

  @impl true
  def init(%RoomState{decay_mode: mode} = room_state) do
    _ = PostDecay.set_decay_timer(mode)

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
  def handle_info(:decay, %RoomState{room: room, decay_mode: mode} = state) do
    _ = PostDecay.set_decay_timer(mode)

    _ = PostDecay.decay_room_posts(room)

    {:noreply, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
end
