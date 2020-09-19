defmodule Gabbler.Story do
  @moduledoc """
  Stories hold the longform additions to original posts that can contain many images. Stories
  also keep the original post in memory for the duration of posting so that edits are saved,
  and collaborative editing is enabled.

  Note that this interface interacts with outside services to maintain image resources.
  """
  alias Gabbler.Accounts.User
  alias Gabbler.Story.Application, as: StoryApp
  alias Gabbler.Story.StoryState
  alias GabblerData.{Post, PostMeta}

  @doc """
  Retrieve either a default state while starting a new server, or return the state of
  and existing server.
  """
  def state(hash) do
    %StoryState{hash: hash}
    |> call(:get_state, nil)
  end

  def state(hash, user, post, post_meta) do
    %StoryState{hash: hash, user: user, post: post, post_meta: post_meta}
    |> call(:get_state, nil)
  end

  @doc """
  Create a unique hash that can be used to start a story server or as a public
  url to share an editing session
  """
  def create_hash(%User{name: name}) do
    {_, _, micro} = :os.timestamp()

    Hashids.new(salt: name, min_len: 12)
    |> Hashids.encode([micro])
  end

  @doc """
  Update a story size by incrementing by the given size
  """
  def get_story_size(story) do
    call(story, :get_size, nil)
  end

  @doc """
  Add/Remove an image to the story
  """
  def add_img(story, %Plug.Upload{} = img) do
    call(story, :add_img, img)
  end

  def remove_image(story, public_id) do
    call(story, :remove_img, public_id)
  end

  def set_imgs(story, imgs) do
    call(story, :set_imgs, imgs)
  end

  @doc """
  Update thumbnail by modifying the posts meta
  """
  def update_thumb(story, thumb_url) do
    call(story, :update_thumb, thumb_url)
  end

  @doc """
  Add/Remove an editor from the story (collaborative editor that navigated to the unique
  editing url)
  """
  def add_editor(story, %User{} = user) do
    call(story, :add_editor, user)
  end

  def remove_editor(story, %User{} = user) do
    call(story, :remove_editor, user)
  end

  @doc """
  Update parts of the state that can be manipulated by outside actions
  """
  def update_post(story, %Post{} = post) do
    call(story, :update_post, post)
  end

  def update_meta(story, %PostMeta{} = post) do
    call(story, :update_meta, post)
  end

  @doc """
  Swap the order of images displayed in the story
  """
  def swap_up(story, public_id) do
    call(story, :swap_up, public_id)
  end

  def swap_down(story, public_id) do
    call(story, :swap_down, public_id)
  end

  @doc """
  Update story order
  """
  def update_story_order(%{imgs: imgs} = _s) do
    update_story_order(imgs, 1)
  end

  def update_story_order([], _), do: :ok
  def update_story_order([%{id: public_id}|t], i) do
    _ = Gabbler.Post.update_story_image_order(public_id, i)

    update_story_order(t, i + 1)
  end

  @doc """
  Note that a user can have only one story active at once
  """
  def server_name(%StoryState{hash: hash}), do: "STORY_#{hash}"

  # PRIVATE FUNCTIONS
  ###################
  defp call(%StoryState{} = story, action, args) do
    case get_story_server_pid(story) do
      {:ok, pid} -> GenServer.call(pid, {action, args})
      {:error, _} -> nil
    end
  end

  defp cast(%StoryState{} = story, action, args) do
    case get_story_server_pid(story) do
      {:ok, pid} -> GenServer.cast(pid, {action, args})
      {:error, _} -> nil
    end
  end

  defp get_story_server_pid(%StoryState{} = story) do
    case :syn.whereis(server_name(story)) do
      :undefined -> StoryApp.add_child(story)
      pid -> {:ok, pid}
    end
  end
end