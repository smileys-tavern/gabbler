defmodule Gabbler.PostRemoval do
  @moduledoc """
  Helping functions for Removing a Post (soft deletes, technically updates)
  NOTE: possible candidate for deprecation (move functionality to post.ex and
  lib/query.ex)
  """
  import Gabbler
  import GabblerWeb.Gettext

  @doc """
  Sequence regarding how data is handled when a moderator removes a post
  """
  def moderator_removal(mod_user, hash) when is_binary(hash) do
    post = Gabbler.Post.get_post(hash)
    room = Gabbler.Room.get(post.room_id)

    if Gabbler.User.moderating?(mod_user, room) do
      post
      |> Ecto.Changeset.change(
        title: gettext("[Deleted by Mod]"),
        body: gettext("[Deleted by Mod]"),
        score_public: 0,
        score_private: 0
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
    post = Gabbler.Post.get_post(hash)

    if post.user_id_post == user.id do
      post
      |> Ecto.Changeset.change(
        title: gettext("[Deleted by User]"),
        body: gettext("[Deleted by User]"),
        score_public: 0,
        score_private: 0
      )
      |> query(:post).update()
    else
      {:error, dgettext("error", "no permission to remove")}
    end
  end
end
