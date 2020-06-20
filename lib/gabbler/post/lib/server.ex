defmodule Gabbler.Post.Server do
  use GenServer

  alias GabblerData.Post
  alias Gabbler.Post.PostState

  # Timeout after 48 hours inactivity
  @server_timeout 1000 * 60 * 60 * 48


  def start_link(%PostState{post: %{hash: hash}} = post_state) do
    GenServer.start_link(
      __MODULE__, post_state, name: Gabbler.Post.server_name(hash), timeout: @server_timeout
    )
  end

  @impl true
  def init(%PostState{} = post_state) do
    {:ok, post_state}
  end

  @impl true
  def handle_call({:get_post, _}, _from, %PostState{post: post} = state) do
    {:reply, post, state}
  end

  @impl true
  def handle_call({:update_post, %Post{} = post}, _from, %PostState{} = state) do
    {:reply, post, %{state | post: post}}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
end
