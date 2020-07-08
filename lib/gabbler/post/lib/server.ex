defmodule Gabbler.Post.Server do
  use GenServer

  alias GabblerData.Post
  alias Gabbler.Post.PostState
  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.Accounts.User

  # Timeout after 48 hours inactivity
  @server_timeout 1000 * 60 * 60 * 48
  @max_chat_msg 30


  def start_link(%PostState{post: %{hash: hash}} = post_state) do
    GenServer.start_link(
      __MODULE__, 
      post_state, 
      name: {:via, :syn, Gabbler.Post.server_name(hash)}, timeout: @server_timeout
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
  def handle_call({:get_chat, _}, _from, %PostState{chat: chat} = state) do
    {:reply, chat, state}
  end

  @impl true
  def handle_cast({:chat_msg, {%User{name: name}, msg}}, %PostState{post: post, chat: chat} = state) do
    _ = GabSub.broadcast("post_chat:#{post.hash}", %{name: name, msg: msg})

    {:noreply, %{state | chat: Enum.take([{name, msg}|chat], @max_chat_msg)}}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
end
