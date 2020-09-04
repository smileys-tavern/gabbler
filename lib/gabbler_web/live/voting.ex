defmodule GabblerWeb.Live.Voting do
  @moduledoc """
  A set of voting handles that any liveview making use of voting can utilize. Expects the socket
  to contain a post or comments. If not found, socket will be replied unaltered. An event is also
  broadcast for those listening in on a room channel.

  TODO: This could probably be a live component
  """
  defmacro __using__(_) do
    quote do
      import GabblerWeb.Gettext
      import Gabbler.Live.SocketUtil, only: [no_reply: 1]
      
      alias Gabbler.Subscription, as: GabSub
      alias GabblerData.Post


      @doc """
      The current user votes
      """
      @impl true
      def handle_event("vote", %{"hash" => hash, "dir" => dir}, %{assigns: assigns} = socket) do
        get_vote_post(assigns, hash)
        |> vote(assigns, dir)
        |> assign_vote(socket, dir)
        |> broadcast_vote()
        |> no_reply()
      end

      @doc """
      A new vote event happens on the current room or post subscription
      (someone else voted on the currently viewed topic)
      """
      @impl true
      def handle_info(%{event: "new_vote", post: %{hash: hash} = post}, %{assigns: assigns} = socket) do
        get_vote_post(assigns, hash)
        |> assign_vote(socket, nil)
        |> get_socket()
        |> no_reply()
      end

      # PRIVATE FUNCTIONS
      ###################
      defp get_vote_post(%{op: %{hash: op_hash} = op}, hash) when op_hash == hash, do: op
      
      defp get_vote_post(%{comments: comments, op: _}, hash) do
        Enum.filter(comments, fn %{hash: comment_hash} -> comment_hash == hash end)
        |> List.first()
      end
      
      defp get_vote_post(%{posts: posts}, hash) do
        Enum.filter(posts, fn %{hash: post_hash} -> post_hash == hash end)
        |> List.first()
      end
      
      defp get_vote_post(_, _), do: nil

      defp vote(nil, _, _), do: nil
      defp vote(post, %{user: user} = assigns, "up"), do: vote(post, user, 1)
      defp vote(post, %{user: user} = assigns, "down"), do: vote(post, user, -1)

      defp vote(%{hash: hash} = post, user, amt) do
        if Gabbler.User.can_vote?(user, hash) do
          case Gabbler.Post.increment_score(post, amt) do
            {1, nil} ->
              Gabbler.User.activity_voted(user, hash)

              {:ok, %{post | :score_public => post.score_public + amt}}
            _ ->
              {:error, dgettext("errors", "there was an issue voting")}
          end
        else
          {:error,
           dgettext(
             "errors",
             "you have reached your voting capacity for today or already voted here"
           )}
        end
      end

      defp assign_vote({:ok, post}, %{assigns: %{comments: comments, room: room}} = socket, dir) do
        comments = replace_post(comments, post, dir)

        {:ok, post, assign(socket, comments: comments)}
      end

      defp assign_vote({:ok, post}, %{assigns: %{posts: posts, room: room}} = socket, dir) do
        posts = replace_post(posts, post, dir)

        {:ok, post, assign(socket, posts: posts)}
      end

      defp assign_vote({:ok, post}, %{assigns: %{posts: posts, rooms: rooms}} = socket, dir) do
        posts = replace_post(posts, post, dir)

        {:ok, post, assign(socket, posts: posts)}
      end

      defp assign_vote({:ok, post}, %{assigns: %{room: room}} = socket, _) do
        {:ok, post, assign(socket, post: post)}
      end

      defp assign_vote({:error, error_str}, socket, _) do
        {:error, error_str, socket}
      end

      defp assign_vote(%Post{} = post, socket, dir), do: assign_vote({:ok, post}, socket, dir)

      defp assign_vote(_, socket, _), do: {:noop, nil, socket}

      # TODO: moving some of this to a broadcasting protocol?
      defp broadcast_vote({:ok, post, %{assigns: %{room: %{name: room_name}}} = socket}) do
        GabSub.broadcast("post_live:#{post.hash}", %{event: "new_vote", post: post})
        GabSub.broadcast("room_live:#{room_name}", %{event: "new_vote", post: post})

        socket
      end

      defp broadcast_vote({:ok, %{id: post_id, hash: hash} = post, %{assigns: %{rooms: rooms}} = socket}) do
        GabSub.broadcast("post_live:#{hash}", %{event: "new_vote", post: post})

        if room = Map.get(rooms, post_id) do
          GabSub.broadcast("room_live:#{room.name}", %{event: "new_vote", post: post})
        end

        socket
      end

      defp broadcast_vote({:error, error_str, %{assigns: %{user: %{id: user_id}}} = socket}) do
        GabSub.broadcast("user:#{user_id}", %{event: "warning", msg: error_str})

        socket
      end

      defp broadcast_vote({:noop, nil, socket}), do: socket

      defp get_socket({_, _, socket}), do: socket

      defp replace_post(posts, post, dir) do
        Enum.map(posts, fn %{hash: hash} = current_post ->
          cond do
            hash == post.hash -> Map.put(post, :voted, dir)
            true -> current_post
          end
        end)
      end
    end
  end
end
