defmodule GabblerWeb.Post.NewLive do
  @moduledoc """
  The Post Creation LiveView page
  """
  use GabblerWeb, :live_view
  use GabblerWeb.Live.Auth, auth_required: [:_page]
  import Gabbler.Live.SocketUtil, only: [no_reply: 1, assign_to: 3]

  alias Gabbler.PostCreation
  alias Gabbler.Room, as: GabblerRoom
  alias Gabbler.Story.Image
  alias Gabbler.Subscription, as: GabSub
  alias GabblerData.{Post, PostMeta}

  @doc """
  Set default form and status of creation
  """
  def mount(params, session, socket) do
    {:ok, init(socket, params, session)}
  end

  @doc """
  Handle events related to the post and story being updated elsewhere (collaborative
  editing and uploading)
  """
  def handle_info(
    %{event: "uploaded", public_id: _pub_id, thumb: _thumb}, 
    %{assigns: %{uploading: u, story: %{hash: hash}, story_pages: story_pages}} = socket) do
    Gabbler.Story.state(hash)
    |> assign_to(:story, socket)
    |> assign(:story_pages, story_pages + 1)
    |> assign(uploading: u - 1)
    |> update_story_size()
    |> sync_from_story()
    |> no_reply()
  end

  def handle_info(%{event: "uploading"}, %{assigns: %{uploading: u}} = socket) do
    socket
    |> assign(uploading: u + 1)
    |> no_reply()
  end

  def handle_info(%{event: "error_uploading", file_name: file_name}, socket) do
    socket
    |> put_flash(:info, gettext("error uploading file") <> " (#{file_name})")
    |> no_reply()
  end

  def handle_info(%{event: "sync_story", state: story_state}, socket) do
    socket
    |> assign(story: story_state)
    |> sync_from_story()
    |> no_reply()
  end

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

  def handle_event("toggle_story_mode", _, %{assigns: %{story_mode: is_on}} = socket) do
    socket
    |> assign(story_mode: !is_on)
    |> no_reply()
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

  def handle_event("open_story_creator", _, socket) do
    socket
    |> assign(story_toggle: :on)
    |> no_reply()
  end

  def handle_event("close_story_creator", _, socket) do
    socket
    |> assign(story_toggle: :off)
    |> no_reply()
  end

  def handle_event("delete_img", %{"id" => public_id}, %{assigns: assigns} = socket) do
    assigns.story
    |> Gabbler.Story.remove_image(public_id)
    |> assign_to(:story, socket)
    |> update_story_size()
    |> sync_from_story()
    |> no_reply()
  end

  def handle_event("update_thumb", %{"id" => public_id}, %{assigns: assigns} = socket) do
    thumb = Enum.find(assigns.story.imgs, nil, fn i -> i.id == public_id end)
    |> Map.get(:thumb)

    Gabbler.Story.update_thumb(assigns.story, thumb)
    |> assign_to(:story, socket)
    |> sync_from_story()
    |> no_reply()
  end

  def handle_event("move_img_up", %{"id" => public_id}, %{assigns: assigns} = socket) do
    Gabbler.Story.swap_up(assigns.story, public_id)
    |> assign_to(:story, socket)
    |> no_reply()
  end

  def handle_event("move_img_down", %{"id" => public_id}, %{assigns: assigns} = socket) do
    Gabbler.Story.swap_down(assigns.story, public_id)
    |> assign_to(:story, socket)
    |> no_reply()
  end

  def handle_event("submit", _, %{assigns: %{mode: :create, user: user, room: room} = assigns} = socket) do
    if GabblerRoom.in_timeout?(room, user) do
      socket
      |> put_flash(:info, gettext("you are in a timeout"))
      |> no_reply()
    else
      socket
      |> assign_new_post(PostCreation.create(user, room, assigns.changeset, assigns.changeset_meta))
      |> broadcast_post_create()
      |> update_story_order()
      |> redirect_if()
      |> no_reply()
    end
  end

  def handle_event("submit", _, %{assigns: %{mode: :update} = assigns} = socket) do
    # TODO: probably the changeset should remain pure until change time instead of
    # mirroring post/meta updates
    changes = %{body: assigns.post.body, title: assigns.post.title}
    changeset = Post.changeset(%Post{
      id: assigns.post.id,
      hash: assigns.post.hash,
      user_id: assigns.post.user_id}, changes)

    meta_changes = %{link: assigns.post_meta.link, thumb: assigns.post_meta.thumb}
    changeset_meta = PostMeta.changeset(%PostMeta{
      id: assigns.post_meta.id,
      user_id: assigns.post.user_id,
      post_id: assigns.post.id
      }, meta_changes)

    socket
    |> assign_updated_post(Gabbler.Post.update(changeset))
    |> assign_updated_meta(Gabbler.Post.update_meta(changeset_meta))
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
  defp init(%{assigns: %{allowed: true} = assigns} = socket, _, _) do
    # TODO Address the large list of defaults for the preview (repeated and ugly)
    story = assigns.story

    assign(socket,
      changeset: Post.changeset(story.post),
      changeset_meta: PostMeta.changeset(story.post_meta),
      post: story.post,
      body: "",
      post_meta: story.post_meta,
      changeset_reply: nil,
      page: 1,
      pages: 1,
      uploading: 0,
      story_mode: false,
      story_page: 0,
      story_view: "single",
      comments: [],
      upload: nil,
      parent: nil,
      story_size: Gabbler.Story.get_story_size(story),
      uploads: Application.get_env(:gabbler, :uploads, :off),
      room_type: "room",
      updated: false,
      user: story.user,
      post_user: story.user,
      mod: false
    )
  end

  defp init(%{assigns: %{user: nil}} = socket, _, _) do
    socket
    |> put_flash(:info, "attempted to access a page for logged in users")
    |> redirect(to: "/")
  end

  defp init(socket, %{"room" => name} = params, session) do
    GabblerRoom.get_room(name)
    |> assign_to(:room, socket)
    |> init(Map.drop(params, ["room"]), session)
  end

  defp init(%{assigns: %{room: room, user: user}} = socket, %{"story_hash" => hash} = params, session) do
    GabSub.subscribe("story:#{hash}")

    story = Gabbler.Story.state(
      hash, 
      user,
      %Post{user_id: user.id, parent_id: room.id, parent_type: "room"},
      %PostMeta{user_id: user.id})
    
    socket
    |> assign(story: story)
    |> assign(story_pages: Enum.count(story.imgs))
    |> assign(mode: :create)
    |> init(Map.drop(params, ["story_hash"]), session)
  end

  defp init(%{assigns: %{user: user}} = socket, %{"hash" => hash} = params, session) do
    post = Gabbler.Post.get_post(hash)

    if post.user_id == user.id do
      meta = Gabbler.Post.get_meta(post)

      story = Gabbler.Story.state(hash, user, post, meta)

      images = Gabbler.Post.get_story_images(meta)
      |> Enum.map(fn %{public_id: id, url: url, thumb: thumb} -> 
        %Image{id: id, url: url, thumb: thumb, size: 0}
      end)

      story = Gabbler.Story.set_imgs(story, images)

      socket
      |> assign(story: story)
      |> assign(story_pages: Enum.count(story.imgs))
      |> assign(mode: :update)
      |> init(Map.drop(params, ["hash"]), session)
    else
      socket
      |> put_flash(:info, gettext("you do not seem to have permission to be here"))
    end
  end

  defp init(%{assigns: %{user: user, room: room}} = socket, params, session) do
    if GabblerRoom.allow_entrance?(room, user, :restricted) do
      socket
      |> assign(room: room)
      |> assign(allowed: true)
      |> assign(story_toggle: :off)
      |> init(params, session)
    else
      socket
      |> assign(room: room)
      |> assign(allowed: false)
      |> assign(story: nil)
      |> assign(story_pages: 0)
      |> assign(story_toggle: :off)
      |> put_flash(:info, gettext("you are either not logged in, banned for life or posting in this room is restricted"))
    end
  end

  defp init(socket, _, _), do: socket

  defp update_story_order(%{assigns: %{story: story}} = socket) do
    _ = Gabbler.Story.update_story_order(story)
    socket
  end

  defp update_story_size(%{assigns: %{story: story}} = socket) do
    socket
    |> assign(story_size: Gabbler.Story.get_story_size(story))
  end

  defp sync_from_story(%{assigns: %{story: story}} = socket) do
    socket
    |> assign(post_meta: story.post_meta)
    |> assign(post: story.post)
    |> assign(changeset: Post.changeset(story.post))
    |> assign(changeset_meta: PostMeta.changeset(story.post_meta))
  end

  defp update_post_assign(%{assigns: %{story: story}} = socket, :body, value) do
    #TODO: look into sanitization options (recently remove html_sanitize_ex due to slow compile)
    sanitized_value = value

    post = Map.put(story.post, :body, sanitized_value)

    socket
    |> assign(story: Gabbler.Story.update_post(story, post), body: value)
    |> sync_from_story()
  end

  defp update_post_assign(%{assigns: %{story: story}} = socket, key, value) do
    post = Map.put(story.post, key, value)

    socket
    |> assign(story: Gabbler.Story.update_post(story, post))
    |> sync_from_story()
  end

  defp update_post_meta_assign(%{assigns: %{story: story}} = socket, key, value) do
    post_meta = Map.put(story.post_meta, key, value)

    socket
    |> assign(story: Gabbler.Story.update_meta(story, post_meta))
    |> sync_from_story()
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
    assign(socket, 
      post: post, 
      changeset: Post.changeset(post),
      updated: update_updated(updated))
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

  defp redirect_if(%{assigns: %{post: %{hash: ""}}} = socket) do
    socket
  end

  defp redirect_if(%{assigns: %{post: %{hash: nil}}} = socket) do
    socket
  end

  defp redirect_if(%{assigns: %{room: %{name: name}, post: %{hash: hash}}} = socket) do
    socket
    |> put_flash(:info, gettext("Posted Successfully!"))
    |> redirect(to: "/r/#{name}/comments/#{hash}/")
  end

  defp redirect_if(socket), do: socket
end
