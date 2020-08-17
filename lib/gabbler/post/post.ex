defmodule Gabbler.Post do
  @moduledoc """
  Each post has it's own server responsible for timed reminders and other actions.

  This module provides an interface to querying said post and maintaining the server so
  long as it is active/unexpired.
  """
  import GabblerWeb.Gettext

  alias Gabbler.PostCreation
  alias Gabbler.Post.Application, as: PostApp
  alias Gabbler.Post.Query, as: QueryPost
  alias Gabbler.Post.PostState
  alias Gabbler.Subscription, as: GabSub
  alias GabblerData.Post

  @default_thread_depth 3
  @max_chat_msg_length 144


  @doc """
  Retrieve a Post, first trying cache, then refreshing cache and Post's server
  """
  def get_post(hash) do
    case QueryPost.get_by_hash(hash) do
      {:cachehit, post} -> post
      {:ok, post} -> call(post, :update_post, post)
      {:error, _} -> nil
    end
  end

  @doc """
  Retrieve a Posts meta, first trying cache
  """
  def get_meta(post) do
    case QueryPost.get_meta(post) do
      {:error, _} -> nil
      {_, post_meta} -> post_meta
    end
  end

  def get_parent(%Post{parent_id: parent_id}) do
    QueryPost.get(parent_id)
  end

  def thread(post, mode, page, level, depth \\ @default_thread_depth)

  def thread(_, _, _, _, 0), do: []

  def thread(post, mode, page, level, depth) do
    QueryPost.thread(post, mode, page, level)
    |> Enum.reduce([], fn thread_post, acc ->
      thread_post = Map.put(thread_post, :comments, comment_count(thread_post))
      acc ++ [thread_post|thread(thread_post, mode, 1, level + 1, depth - 1)]
    end)
  end

  @doc """
  Map a set of posts to their meta data
  """
  def map_metas(posts) do
    QueryPost.map_meta(posts)
  end

  @doc """
  Map a set of posts to it's user data
  """
  def map_users(posts) do
    QueryPost.map_users(posts)
  end

  @doc """
  Persist a reply and broadcast the resulting information to interested parties
  """
  def reply_submit(changeset, room, op, user) do
    QueryPost.create_reply(PostCreation.prepare_changeset(room, changeset))
    |> notify_user()
    |> update_comment_parent(op, room, user)
  end

  @doc """
  Post a chat msg and return :ok or :error depending on delivery success
  """
  def chat_msg(post, user, msg) do
    cond do
      String.length(msg) > @max_chat_msg_length -> :error
      Gabbler.User.can_chat?(user) -> cast(post, :chat_msg, {user, msg})
      true -> :timer      
    end
  end

  @doc """
  Retrieve the current chat
  """
  def get_chat(post), do: call(post, :get_chat, nil)

  @doc """
  Mark and broadcast that a post/comment has an additional comment under it.
  We use the id only as it is often available as a parent
  """
  def tally_comment(post_id) do
    QueryPost.tally_comment(post_id)
  end

  @doc """
  Retrieve the comment count from memory for a post
  """
  def comment_count(post), do: QueryPost.comment_count(post)

  def server_name(hash) when is_binary(hash), do: "POST_#{hash}"

  # PRIVATE FUNCTIONS
  ###################
  defp call(%Post{parent_type: "room"} = post, action, args) do
    # Only top level (Original) posts have servers
    case get_post_server_pid(post) do
      {:ok, pid} -> GenServer.call(pid, {action, args})
      {:error, _} -> nil
    end
  end

  defp call(post, _, _), do: post

  defp cast(%Post{parent_type: "room"} = post, action, args) do
    # Only top level (Original) posts have servers
    case get_post_server_pid(post) do
      {:ok, pid} -> GenServer.cast(pid, {action, args})
      {:error, _} -> :error
    end
  end

  defp cast(_, _, _), do: :error

  defp get_post_server_pid(%Post{hash: hash} = post) do
    case :syn.whereis(server_name(hash)) do
      :undefined -> PostApp.add_child(%PostState{post: post})
      pid -> {:ok, pid}
    end
  end

  defp notify_user({:ok, %{parent_id: parent_id} = comment}) do
    %{user_id: user_id} = QueryPost.get(parent_id)

    _ = Gabbler.User.add_activity(user_id, parent_id, "reply")

    {:ok, comment}
  end

  defp update_comment_parent({:ok, comment}, op, room, _) do
    new_count = tally_comment(comment.parent_id)

    GabSub.broadcast(
      "post_live:#{op.hash}", 
      %{event: "new_reply", post: comment, count: new_count})

    if op.parent_type == "room" do
      GabSub.broadcast(
        "room_live:#{room.name}", 
        %{event: "comment_count", id: op.id, count: new_count})      
    end

    {:ok, comment}
  end

  defp update_comment_parent({:error, changeset}, _, _, user) do
    Gabbler.User.broadcast(user, gettext("there was an issue sending your reply"), "warning")

    {:error, changeset}
  end
end