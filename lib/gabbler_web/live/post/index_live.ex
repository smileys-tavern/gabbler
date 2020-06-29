defmodule GabblerWeb.Post.IndexLive do
  @moduledoc """
  The Post Page LiveView and post sub-categories like comment focus pages
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: ["reply", "reply_submit", "reply_comment", "vote", "subscribe"]
  use GabblerWeb.Live.Voting
  use GabblerWeb.Live.Room
  use GabblerWeb.Live.Konami, timeout: 5000
  import Gabbler.Live.SocketUtil, only: [no_reply: 1, update_changeset: 5, assign_to: 3]

  alias Gabbler.Subscription, as: GabSub
  alias Gabbler.{PostCreation, PostRemoval}
  alias Gabbler.Post, as: GabblerPost
  alias Gabbler.Room, as: GabblerRoom
  alias GabblerWeb.Presence
  alias GabblerData.{Post, PostMeta, Comment, Room}
  alias Gabbler.Accounts.User

  @default_mode :hot


  def mount(params, session, socket) do
    {:ok, init(assign_defaults(socket), params, session)}
  end

  def handle_info(%{event: "new_reply", post: comment}, socket) do
    assign_comment(socket, comment)
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

  def handle_event("page_up", _, %{assigns: %{page: current_page}} = socket) do
    change_page(socket, current_page + 1)
    |> no_reply()
  end

  def handle_event("page_down", _, %{assigns: %{page: current_page}} = socket) do
    change_page(socket, current_page - 1)
    |> no_reply()
  end

  def handle_event("reply_comment", %{"to" => parent_hash}, %{assigns: assigns} = socket) do
    if GabblerRoom.in_timeout?(assigns.room, assigns.user) do
      socket
      |> put_flash(:info, "you are in a timeout")
      |> no_reply()
    else
      open_reply_to(socket, query(:post).get_by_hash(parent_hash))
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

  def handle_event("reply_submit", _, %{assigns: %{room: room, changeset_reply: changeset}} = socket) do
    add_reply(socket, query(:post).create_reply(PostCreation.prepare_changeset(room, changeset)))
    |> broadcast_reply()
    |> assign_form_reply_defaults()
    |> no_reply()
  end

  def handle_event("post_edit", %{"hash" => _hash, "body" => _body}, socket), do: no_reply(socket)

  def handle_event("hide_thread", %{"id" => hide_comment_id}, socket) do
    hide_thread(socket, hide_comment_id)
    |> no_reply()
  end

  def handle_event("delete_post", %{"hash" => hash}, %{assigns: %{user: user}} = socket) do
    socket
    |> state_update_post(PostRemoval.moderator_removal(user, hash))
    |> no_reply()
  end

  # PRIV
  #############################
  defp init(socket, %{"mode" => mode, "hash" => op_hash} = params, session) 
  when mode in ["hot", "new", "live"] do
    if mode == "live" do
      GabSub.subscribe("post_live:#{op_hash}")
    end

    assign(socket, :mode, String.to_atom(mode))
    |> init(Map.drop(params, ["mode"]), session)
  end

  defp init(socket, %{"hash" => hash, "focushash" => focus_hash} = params, session) do
    socket
    |> assign(:post, query(:post).get_by_hash(focus_hash))
    |> assign(:op, query(:post).get_by_hash(hash))
    |> assign(:focus_hash, focus_hash)
    |> init(Map.drop(params, ["hash", "focushash"]), session)    
  end

  defp init(socket, %{"hash" => hash} = params, session) do
    socket = socket
    |> assign(:post, query(:post).get_by_hash(hash))
    |> assign(:focus_hash, nil)

    socket
    |> assign(:op, socket.assigns.post)
    |> init(Map.drop(params, ["hash"]), session)
  end

  defp init(socket, %{"focushash" => focus_hash} = params, session) do
    post = GabblerPost.get_post(focus_hash)

    socket
    |> assign(:post, post)
    |> assign(:focus_hash, focus_hash)
    |> assign(:op, GabblerPost.get_parent(post))
    |> init(Map.drop(params, ["focushash"]), session)
  end

  defp init(%{assigns: %{post: post, mode: mode, room: room, user: user}} = socket, _, _) do
    assign(socket,
      comments: GabblerPost.thread(post, mode, 1, 1),
      post_user: query(:user).get(post.user_id),
      pages: query(:post).page_count(post),
      changeset_reply: default_reply_changeset(user, room, post),
      reply: default_reply(user, room, post)
    )
  end

  defp assign_defaults(socket) do
    socket
    |> assign(:mode, @default_mode)
    |> assign(:post, nil)
    |> assign(:op, nil)
    |> assign(:room, nil)
    |> assign(:reply_display, "hidden")
    |> assign(:reply_comment_display, "hidden")
    |> assign(:parent, nil)
    |> assign(:page, 1)
    |> assign(:post_meta, %PostMeta{})
  end

  defp add_reply(%{assigns: %{op: op, comments: comments}} = socket, {:ok, comment}) do
    post = query(:post).get(comment.parent_id)

    # Inform user of parent post of reply (TODO: move out of this module)
    _ = Gabbler.User.add_activity(post.user_id, post.id, "reply")

    socket = socket
    |> assign(comments: add_comment(op, comment, comments), reply_display: "hidden", reply_comment_display: "hidden")

    {:ok, comment, socket}
  end

  defp add_reply(socket, {:error, changeset}) do
    {:error, nil, assign(socket, changeset_reply: changeset)}
  end

  defp broadcast_reply({:ok, comment, %{assigns: %{op: %{hash: op_hash}}} = socket}) do
    GabSub.broadcast("post_live:#{op_hash}", %{event: "new_reply", post: comment})

    socket
  end

  defp broadcast_reply({:error, _, %{assigns: %{user: user}} = socket}) do
    Gabbler.User.broadcast(user, gettext("there was an issue sending your reply"), "warning")

    socket
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

  defp change_page(%{assigns: %{post: post, mode: mode}} = socket, page_new) do
    comments = query(:post).thread(post, mode, page_new)

    assign(socket, page: page_new, comments: comments)
  end

  defp assign_comment(%{assigns: %{op: op, comments: comments}} = socket, comment) do
    assign(socket,
      comments: add_comment(op, comment, comments),
      pages: query(:post).page_count(op)
    )
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

  defp state_update_post(socket, {:ok, post}), do: state_update_post(socket, post)

  defp state_update_post(
         %{assigns: %{op: op, comments: comments}} = socket,
         %{id: id, body: body} = post
       ) do
    if op.id == id do
      assign(socket, op: post)
    else
      comments =
        Enum.map(comments, fn %{id: c_id} = comment ->
          if c_id == id do
            %{comment | body: body, score_public: 0}
          else
            comment
          end
        end)

      assign(socket, comments: comments)
    end
  end
end
