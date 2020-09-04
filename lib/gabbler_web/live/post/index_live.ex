defmodule GabblerWeb.Post.IndexLive do
  @moduledoc """
  The Post Page LiveView and post sub-categories like comment focus pages
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: [
    "reply", "reply_submit", "reply_comment", 
    "vote", "subscribe", "chat_msg"]
  use GabblerWeb.Live.Voting
  use GabblerWeb.Live.Room
  use GabblerWeb.Live.Konami, timeout: 5000
  import Gabbler.Live.SocketUtil, only: [no_reply: 1, update_changeset: 5, assign_to: 3]

  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.Post, as: GabblerPost
  alias Gabbler.Room, as: GabblerRoom
  alias Gabbler.User, as: GabblerUser
  alias GabblerWeb.Presence
  alias GabblerData.{Post, PostMeta, Comment, Room}
  alias Gabbler.Accounts.User

  @default_mode :live
  @max_chat_shown 30


  def mount(params, session, socket) do
    {:ok, init(assign_defaults(socket), params, session)}
  end

  def handle_info(%{event: "new_reply", post: comment, count: count}, %{assigns: assigns} = socket) do
    assigns.comments
    |> Enum.reduce([], fn %{id: id} = c, acc ->
      if id == comment.parent_id do
        [Map.put(c, :comments, count)|acc]
      else
        [c|acc]
      end
    end)
    |> Enum.reverse()
    |> assign_to(:comments, socket)
    |> assign_comment(comment)
    |> no_reply()
  end

  def handle_info(%{name: user_name, msg: msg}, %{assigns: %{chat: chat}} = socket) do
    socket
    |> assign(chat: Enum.take([{user_name, msg}|chat], @max_chat_shown))
    |> no_reply()
  end

  def handle_event("reply", %{"to" => _}, %{assigns: %{post: post} = assigns} = socket) do
    if GabblerRoom.in_timeout?(assigns.room, assigns.user) do
      socket
      |> put_flash(:info, "you are in a timeout")
      |> no_reply()
    else
      socket
      |> update_changeset(:changeset_reply, :reply, :parent_id, post.id)
      |> assign(reply_display: "block")
      |> no_reply()
    end
  end

  def handle_event("reply", _, socket), do: no_reply(socket)

  def handle_event("story_page_up", _, %{assigns: %{story_page: story_page}} = socket) do
    socket
    |> assign(story_page: story_page + 1)
    |> no_reply()
  end

  def handle_event("story_page_down", _, %{assigns: %{story_page: story_page}} = socket) do
    socket
    |> assign(story_page: story_page - 1)
    |> no_reply()
  end

  def handle_event("story_view_change", %{"view" => view}, socket) when view in ["single", "double"] do
    socket
    |> assign(story_view: view)
    |> no_reply()
  end

  def handle_event("page_up", _, %{assigns: %{page: current_page}} = socket) do
    change_page(socket, current_page + 1)
    |> no_reply()
  end

  def handle_event("page_down", _, %{assigns: %{page: current_page}} = socket) do
    change_page(socket, current_page - 1)
    |> no_reply()
  end

  def handle_event("chat_msg", _, %{assigns: %{user: nil}} = socket) do
    socket
    |> no_reply()
  end

  def handle_event("chat_msg", %{"msg" => msg}, %{assigns: assigns} = socket) do
    if GabblerRoom.in_timeout?(assigns.room, assigns.user) do
      socket
      |> put_flash(:info, gettext("you are in a timeout"))
      |> no_reply()
    else
      case GabblerPost.chat_msg(assigns.post, assigns.user, msg) do
        :timer ->
          socket
          |> put_flash(:info, gettext("please wait a few seconds between messages"))
          |> no_reply()
        :error -> 
          socket
          |> put_flash(:info, gettext("message was not delivered"))
          |> no_reply()
        :ok -> 
          socket
          |> assign(chat_msg: "")
          |> no_reply()
      end
    end
  end

  def handle_event("toggle_story_mode", _, %{assigns: %{story_mode: is_on}} = socket) do
    socket
    |> assign(story_mode: !is_on)
    |> no_reply()
  end

  def handle_event("reply_comment", %{"to" => parent_hash}, %{assigns: assigns} = socket) do
    if GabblerRoom.in_timeout?(assigns.room, assigns.user) do
      socket
      |> put_flash(:info, gettext("you are in a timeout"))
      |> no_reply()
    else
      open_reply_to(socket, GabblerPost.get_post(parent_hash))
      |> no_reply()
    end
  end

  def handle_event("reply_hide", _, socket) do
    assign(socket, reply_display: "hidden")
    |> no_reply()
  end

  def handle_event("reply_comment_hide", _, socket) do
    assign(socket, reply_comment_display: "hidden")
    |> no_reply()
  end

  def handle_event("reply_change", %{"_target" => ["reply", "body"], "reply" => %{"body" => body}}, socket) do
    update_changeset(socket, :changeset_reply, :reply, :body, body)
    |> no_reply()
  end

  def handle_event("reply_submit", _, %{assigns: assigns} = socket) do
    Gabbler.Post.reply_submit(assigns.changeset_reply, assigns.room, assigns.op, assigns.user)
    |> add_reply(socket)
    |> assign_form_reply_defaults()
    |> no_reply()
  end

  def handle_event("post_edit", %{"hash" => _hash, "body" => _body}, socket), do: no_reply(socket)

  def handle_event("hide_thread", %{"id" => hide_comment_id}, socket) do
    hide_thread(socket, hide_comment_id)
    |> no_reply()
  end

  # PRIV
  #############################
  defp init(socket, %{"mode" => mode} = params, session) 
  when mode in ["hot", "new", "live", "chat"] do
    socket
    |> assign(:mode, String.to_atom(mode))
    |> init(Map.drop(params, ["mode"]), session)
  end

  defp init(socket, %{"hash" => hash, "focushash" => focus_hash} = params, session) do
    socket
    |> assign(:post, Gabbler.Post.get_post(focus_hash))
    |> assign(:op, Gabbler.Post.get_post(hash))
    |> assign(:focus_hash, focus_hash)
    |> init(Map.drop(params, ["hash", "focushash"]), session)    
  end

  defp init(socket, %{"hash" => hash} = params, session) do
    post = Gabbler.Post.get_post(hash)
    meta = GabblerPost.get_meta(post)
    story = GabblerPost.get_story_images(meta)

    socket
    |> assign(:post, post)
    |> assign(:post_meta, meta)
    |> assign(:focus_hash, nil)
    |> assign(:story, %{imgs: story})
    |> assign(:story_pages, Enum.count(story))
    |> assign(:op, post)
    |> init(Map.drop(params, ["hash"]), session)
  end

  defp init(socket, %{"focushash" => focus_hash} = params, session) do
    post = GabblerPost.get_post(focus_hash)
    meta = GabblerPost.get_meta(post)
    story = GabblerPost.get_story_images(meta)

    socket
    |> assign(:post, post)
    |> assign(:post_meta, meta)
    |> assign(:story, %{imgs: story})
    |> assign(:story_pages, Enum.count(story))
    |> assign(:focus_hash, focus_hash)
    |> assign(:op, GabblerPost.get_parent(post))
    |> init(Map.drop(params, ["focushash"]), session)
  end

  defp init(%{assigns: %{post: post, mode: mode, room: room, user: user, op: op}} = socket, _, _) do
    if mode == :live do
      GabSub.subscribe("post_live:#{op.hash}")
    end

    chat = case mode do
      :chat -> GabblerPost.get_chat(post)
      _ -> nil
    end

    socket
    |> assign(comments: GabblerPost.thread(post, mode, 1, 1),
      chat: chat,
      chat_msg: "",
      post_user: GabblerUser.get(post.user_id),
      pages: GabblerPost.page_count(post),
      changeset_reply: default_reply_changeset(user, room, post),
      reply: default_reply(user, room, post)
    )
  end

  defp assign_defaults(socket) do
    socket
    |> assign(:mode, @default_mode)
    |> assign(:post, nil)
    |> assign(:op, nil)
    |> assign(:story_mode, false)
    |> assign(:room, nil)
    |> assign(:reply_display, "hidden")
    |> assign(:reply_comment_display, "hidden")
    |> assign(:chat, nil)
    |> assign(:story_page, 0)
    |> assign(:story_view, "single")
    |> assign(:story_pages, 0)
    |> assign(:chat_msg, "")
    |> assign(:story, %{imgs: []})
    |> assign(:parent, nil)
    |> assign(:page, 1)
    |> assign(:post_meta, %PostMeta{})
  end

  defp add_reply({:ok, comment}, %{assigns: assigns} = socket) do
    socket
    |> assign(comments: add_comment(assigns.op, comment, assigns.comments))
    |> assign(reply_display: "hidden", reply_comment_display: "hidden")
  end

  defp add_reply({:error, changeset}, socket) do
    assign(socket, changeset_reply: changeset)
  end

  defp assign_form_reply_defaults(%{assigns: %{op: op, room: room, user: user}} = socket) do
    assign(socket,
      changeset_reply: default_reply_changeset(user, room, op),
      reply: default_reply(user, room, op)
    )
  end

  defp hide_thread(%{assigns: %{comments: comments}} = socket, comment_id) do
    # Currently ugly logic to comb through comments and remove greater than depth at which thread is
    # being hidden
    Enum.reduce(comments, {[], false, 0}, fn %{id: id, depth: depth} = comment, {acc, in_thread, at_depth} ->
      if id == comment_id || (in_thread && depth > at_depth) do
        {acc, true, depth}
      else
        {[comment | acc], false, at_depth}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> assign_to(:comments, socket)
  end

  defp open_reply_to(socket, %{id: post_id}) do
    socket
    |> update_changeset(:changeset_reply, :reply, :parent_id, post_id)
    |> assign(reply_comment_display: "block")
  end

  defp change_page(%{assigns: %{post: post, mode: mode}} = socket, page) do
    post
    |> GabblerPost.thread(mode, page, 1)
    |> assign_to(:comments, socket)
    |> assign(page: page)
  end

  defp assign_comment(%{assigns: %{op: op, comments: comments}} = socket, comment) do
    add_comment(op, Map.put(comment, :status, "arrived"), comments)
    |> Enum.uniq_by(fn c -> c.id end)
    |> assign_to(:comments, socket)
    |> assign(pages: GabblerPost.page_count(op))
  end

  defp add_comment(%{id: op_id}, %{parent_id: parent_id} = new_comment, comments) do
    if op_id == parent_id do
      [new_comment | comments]
    else
      Enum.reduce(comments, [], fn comment, acc ->
        case comment do
          %{id: id, depth: depth} when id == parent_id ->
            [Map.put(new_comment, :depth, depth + 1), comment | acc]
          _ ->
            [comment | acc]
        end
      end)
      |> Enum.reverse()
    end
  end

  defp default_reply_changeset(%User{} = user, %Room{} = room, %Post{} = post) do
    Comment.changeset(default_reply(user, room, post))
  end

  defp default_reply_changeset(nil, _, _), do: nil

  defp default_reply(%User{id: user_id}, %Room{id: room_id}, %Post{id: op_id, hash: op_hash}),
    do: %Comment{
      title: "reply",
      room_id: room_id,
      parent_id: op_id,
      parent_type: "comment",
      user_id: user_id,
      age: 0,
      hash_op: op_hash,
      score_public: 1,
      score_private: 1,
      score_alltime: 1
    }

  defp default_reply(nil, _, _), do: nil
end
