defmodule Gabbler.Story.Application do
  use DynamicSupervisor

  alias Gabbler.Story.StoryState
  alias Gabbler.Story.Server, as: StoryServer

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def add_child(%StoryState{} = post_story_state) do
    child_spec = {StoryServer, post_story_state}

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def remove_child(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def children() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children do
    DynamicSupervisor.count_children(__MODULE__)
  end
end
