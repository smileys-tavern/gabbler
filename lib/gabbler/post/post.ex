defmodule Gabbler.Post do
  @moduledoc """
  Each post has it's own server responsible for timed reminders and other actions.

  This module provides an interface to querying said post and maintaining the server so
  long as it is active/unexpired.
  """
  alias Gabbler.Post.Application, as: PostApp
  alias Gabbler.Post.Query, as: QueryPost
  alias Gabbler.Post.PostState
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

  def get_parent(%Post{parent_id: parent_id}) do
    QueryPost.get(parent_id)
  end

  def thread(post, mode, page, level, depth \\ @default_thread_depth)

  def thread(_, _, _, _, 0), do: []

  def thread(post, mode, page, level, depth) do
    QueryPost.thread(post, mode, page, level)
    |> Enum.reduce([], fn thread_post, acc ->
      acc ++ [thread_post|thread(thread_post, mode, 1, level + 1, depth - 1)]
    end)
  end

  def map_metas(posts) do
    QueryPost.map_meta(posts)
  end

  def map_users(posts) do
    QueryPost.map_users(posts)
  end

  @doc """
  Post a chat msg and return :ok or :error depending on delivery success
  """
  def chat_msg(post, user, msg) do
    if String.length(msg) > @max_chat_msg_length do
      :error
    else
      cast(post, :chat_msg, {user, msg})
    end
  end

  @doc """
  Retrieve the current chat
  """
  def get_chat(post) do
    call(post, :get_chat, nil)
  end

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

  defp cast(post, _, _), do: :error

  defp get_post_server_pid(%Post{hash: hash} = post) do
    case :syn.whereis(server_name(hash)) do
      :undefined -> PostApp.add_child(%PostState{post: post})
      pid -> {:ok, pid}
    end
  end
end