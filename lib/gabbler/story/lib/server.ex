defmodule Gabbler.Story.Server do
  use GenServer

  alias Gabbler.Story.{StoryState, Images, Image}
  alias Gabbler.Subscription, as: GabSub

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
  def handle_call({:get_state, _}, _f, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_thumb, thumb}, _f, %{post_meta: meta} = state) do
    meta = %{meta | thumb: thumb}
    state = %{state | post_meta: meta}

    {:reply, state, state}
  end

  @impl true
  def handle_call({:get_size, _}, _f, %{imgs: imgs} = state) do
    size = Enum.reduce(imgs, 0, fn %{size: size}, acc -> size + acc end)

    {:reply, size, state}
  end

  @impl true
  def handle_call({:add_img, img}, _f, %{hash: hash, imgs: imgs, post_meta: meta} = state) do
    case Images.upload(state, img) do
      {:ok, _, %Image{id: public_id, thumb: thumb} = uploaded_img} ->
        _ = GabSub.broadcast("story:#{hash}", %{
          event: "uploaded",
          public_id: public_id,
          thumb: thumb
        })

        meta = Map.put(meta, :image, hash)

        state = if Map.get(meta, :thumb) do
          state
        else
          meta = Map.put(meta, :thumb, thumb)

          %{state | post_meta: meta}
        end
        
        {:reply, uploaded_img, %{state | imgs: [uploaded_img|imgs]}}        
      {:error, file_name} ->
        _ = GabSub.broadcast("story:#{hash}", %{
          event: "error_uploading",
          file_name: file_name
        })

        {:reply, {:error, file_name}, state}
    end
  end

  @impl true
  def handle_call({:remove_img, public_id}, _f, %{imgs: imgs} = state) do
    _ = Images.destroy_image(public_id)

    imgs = Enum.filter(imgs, fn i -> i.id != public_id end)
    state = %{state | imgs: imgs}
    
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_post, post}, _f, %{hash: hash} = state) do
    state = %{state | post: post}

    _ = GabSub.broadcast("story:#{hash}", %{event: "sync_story", state: state})

    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_meta, meta}, _f, %{hash: hash} = state) do
    state = %{state | post_meta: meta}

    _ = GabSub.broadcast("story:#{hash}", %{event: "sync_story", state: state})

    {:reply, state, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
end
