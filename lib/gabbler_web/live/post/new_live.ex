defmodule GabblerWeb.Post.NewLive do
  @moduledoc """
  The Post Creation LiveView page
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: [:_page]
  import Gabbler, only: [query: 1]
  import Gabbler.Live.SocketUtil, only: [no_reply: 1]

  alias Gabbler.PostCreation
  alias Gabbler.Room, as: GabblerRoom
  alias Gabbler.Subscription, as: GabSub
  alias GabblerData.{Post, PostMeta}

  @doc """
  Set default form and status of creation
  """
  def mount(params, session, socket) do
    {:ok, init(socket, params, session)}
  end

  @doc """
  Handle a form update event where Post parameters were adjusted or the Post create/update form was submit
  """
  def handle_event("update_post", %{"_target" => ["post", "title"], "post" => %{"title" => title}}, socket) do
    update_post_assign(socket, :title, title)
    |> no_reply()
  end

  def handle_event("update_post", %{"_target" => ["post", "body"], "post" => %{"body" => body}}, socket) do
    update_post_assign(socket, :body, body)
    |> no_reply()
  end

  def handle_event("update_post", %{"_target" => ["post_meta", "link"], "post_meta" => %{"link" => link}}, socket) do
    update_post_meta_assign(socket, :link, link)
    |> no_reply()
  end

  def handle_event("update_post", %{"_target" => ["post_meta", "image"], "post_meta" => %{"image" => image}}, socket) do
    assign(socket, upload: image)
    |> no_reply()
  end

  def handle_event("update_post", %{"_target" => ["post_meta", "tags"], "post_meta" => %{"tags" => tags}}, socket) do
    update_post_meta_assign(socket, :tags, tags)
    |> no_reply()
  end

  def handle_event("update_post", _, socket), do: {:noreply, socket}

  def handle_event("submit", _, %{assigns: %{mode: :create, user: user, room: room} = assigns} = socket) do
    if GabblerRoom.in_timeout?(room, user) do
      socket
      |> put_flash(:info, gettext("you are in a timeout"))
      |> no_reply()
    else
      assign_new_post(socket, PostCreation.create(user, room, assigns.changeset, assigns.changeset_meta))
      |> broadcast_post_create()
      |> no_reply()
    end
  end

  def handle_event("submit", _, %{assigns: %{mode: :update} = assigns} = socket) do
    assign_updated_post(socket, query(:post).update(assigns.changeset))
    |> assign_updated_meta(query(:post).update_meta(assigns.changeset_meta))
    |> no_reply()
  end

  def handle_event("submit", _, %{assigns: %{mode: :create}} = socket) do
    {:noreply, socket}
  end

  def handle_event("reply", _, socket) do
    {:noreply, socket}
  end

  # PRIV
  #############################
  defp init(%{assigns: %{user: %{id: user_id} = user, room: %{id: room_id}}} = socket, _, _) do
    # TODO Address the large list of defaults for the preview (repeated and ugly)
    assign(socket,
      changeset: %Post{user_id: user_id, parent_id: room_id, parent_type: "room"}
        |> Post.changeset(),
      changeset_meta: PostMeta.changeset(%PostMeta{user_id: user_id}),
      post: %Post{user_id: user_id},
      body: "",
      post_meta: %PostMeta{user_id: user_id},
      changeset_reply: nil,
      page: 1,
      pages: 1,
      comments: [],
      upload: nil,
      parent: nil,
      uploads: Application.get_env(:gabbler, :uploads, :off),
      room_type: "room",
      mode: :create,
      updated: false,
      user: user,
      post_user: user,
      mod: false
    )
  end

  defp init(%{assigns: assigns} = socket, %{"room" => name} = params, session) do
    room = GabblerRoom.get_room(name)

    if GabblerRoom.allow_entrance?(room, assigns.user) do
      socket
      |> assign(room: room)
      |> assign(allowed: true)
      |> init(session, params)
    else
      socket
      |> assign(room: room)
      |> assign(allowed: false)
      |> put_flash(:info, gettext("you are either banned for life or posting here is restricted"))
    end
  end

  defp init(socket, _, _), do: socket

  defp update_post_assign(%{assigns: %{post: post, changeset: changeset}} = socket, :body, value) do
    #TODO: look into sanitization options (recently remove html_sanitize_ex due to slow compile)
    sanitized_value = value

    post = Map.put(post, :body, sanitized_value)

    assign(socket,
      post: post,
      body: value,
      changeset: update_changeset(changeset, :body, sanitized_value)
    )
  end

  defp update_post_assign(%{assigns: %{post: post, changeset: changeset}} = socket, key, value) do
    post = Map.put(post, key, value)

    assign(socket,
      post: post,
      changeset: update_changeset(changeset, key, value)
    )
  end

  defp update_post_meta_assign(%{assigns: %{post_meta: post_meta, changeset_meta: changeset}} = socket, key, value) do
    post_meta = Map.put(post_meta, key, value)

    assign(socket,
      post_meta: post_meta,
      changeset_meta: update_changeset_meta(changeset, key, value)
    )
  end

  defp update_changeset(changeset, key, value) do
    changeset = %{changeset | :errors => Keyword.delete(changeset.errors, key)}
    |> Post.changeset(%{key => value})

    case changeset do
      %{:errors => []} -> %{changeset | :valid? => true}
      _ -> changeset
    end
  end

  defp update_changeset_meta(changeset, key, value) do
    changeset =
      %{changeset | :errors => Keyword.delete(changeset.errors, key)}
      |> PostMeta.changeset(%{key => value})

    case changeset do
      %{:errors => []} -> %{changeset | :valid? => true}
      _ -> changeset
    end
  end

  defp update_updated(false), do: 1
  defp update_updated(updated), do: updated + 1

  defp assign_new_post(%{assigns: %{user: user, updated: updated}} = socket, {:ok, {post, meta}}) do
    _users_posts = Gabbler.User.activity_posted(user, post.hash)

    _ = Gabbler.TagTracker.add_tags(post, meta)

    {:ok, assign(socket,
      post: post,
      post_meta: meta,
      changeset: Post.changeset(post),
      changeset_meta: PostMeta.changeset(meta),
      mode: :update,
      updated: update_updated(updated)
    )}
  end

  defp assign_new_post(socket, {:error, {:post, changeset}}), do: {:error, assign(socket, changeset: changeset)}
  defp assign_new_post(socket, {:error, {:post_meta, changeset}}), do: {:error, assign(socket, changeset_meta: changeset)}
  defp assign_new_post(%{assigns: %{user: user}} = socket, {:error, error_str}) do
    GabSub.broadcast("user:#{user.id}", %{event: "warning", msg: error_str})

    {:error, socket}
  end

  defp assign_updated_post(%{assigns: %{updated: updated}} = socket, {:ok, post}) do
    assign(socket, post: post, changeset: Post.changeset(post), updated: update_updated(updated))
  end

  defp assign_updated_post(socket, {:error, changeset}) do
    assign(socket, changeset: changeset)
  end

  defp assign_updated_meta(socket, {:ok, meta}) do
    assign(socket, post_meta: meta, changeset_meta: PostMeta.changeset(meta))
  end

  defp assign_updated_meta(socket, {:error, changeset}) do
    assign(socket, changeset_meta: changeset)
  end

  defp broadcast_post_create({:ok, %{assigns: %{room: room, post: post, post_meta: meta, user: user}} = socket}) do
    GabblerWeb.Endpoint.broadcast("room_live:#{room.name}", "new_post", %{
      :post => post,
      :meta => meta
    })

    GabblerWeb.Endpoint.broadcast("user:#{user.id}", "new_post", %{
      :post => post,
      :meta => meta
    })

    socket
  end

  defp broadcast_post_create({:error, socket}), do: socket
end
