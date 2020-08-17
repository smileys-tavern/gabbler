defmodule Gabbler.Story.Server do
  use GenServer

  alias Gabbler.Story.StoryState
  alias Gabbler.Accounts.User

  # 2 hour timeout if inactive
  @server_timeout 1000 * 60 * 60 * 2

  def start_link(%StoryState{} = story_state) do
    GenServer.start_link(
      __MODULE__, 
      story_state, 
      name: {:via, :syn, Gabbler.Story.server_name(story_state)}, timeout: @server_timeout
    )
  end

  @impl true
  def init(%StoryState{} = post_state) do
    {:ok, post_state}
  end

  @impl true
  def handle_call({:add_img, img}, _from, %{imgs: imgs} = state) do
    {:reply, [img|imgs], %{state | imgs: [img|imgs]}}
  end

  @impl true
  def handle_call({:get_state, _}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
end
