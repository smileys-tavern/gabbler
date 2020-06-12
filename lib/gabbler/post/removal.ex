defmodule Gabbler.PostRemoval do
  @moduledoc """
  Helping functions for Removing a Post (soft deletes, technically updates)
  """
  import Gabbler
  import GabblerWeb.Gettext

  @doc """
  Sequence regarding how data is handled when a moderator removes a post
  """
  def moderator_removal(mod_user, hash) when is_binary(hash) do
    post = query(:post).get(hash)
    room = query(:room).get(post.room_id)

    if Gabbler.User.moderating?(mod_user, room) do
      post
      |> Ecto.Changeset.change(
        title: gettext("[Deleted by Mod]"),
        body: gettext("[Deleted by Mod]"),
        score_public: 0
      )
      |> query(:post).update()
    else
      {:error, dgettext("error", "no permission to remove")}
    end
  end

  @doc """
  Sequence regarding how data is handled when a user removes their own post
  """
  def user_removal(user, hash) when is_binary(hash) do
    post = query(:post).get(hash)

    if post.user_id_post == user.id do
      post
      |> Ecto.Changeset.change(
        title: gettext("[Deleted by Mod]"),
        body: gettext("[Deleted by Mod]"),
        score_public: 0
      )
      |> query(:post).update()
    else
      {:error, dgettext("error", "no permission to remove")}
    end
  end
end
