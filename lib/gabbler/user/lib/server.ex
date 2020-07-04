defmodule Gabbler.User.Server do
  use GenServer

  alias Gabbler.User.ActivityModel
  alias Gabbler.Accounts.User

  # TODO: lets have these in config
  # Hours
  @vote_limit_expirey 24
  @max_votes 10
  # Hours
  @post_limit_expirey 1
  @max_posts 3
  # Max in activity server
  @max_subscriptions 7
  # Max in activity server
  @max_moderating 5
  # Max new activity shown at once
  @max_activity 10
  # Server deletes after 48 hours inactivity
  @server_timeout 1000 * 60 * 60 * 48

  def start_link({%User{} = user, subs, moderating}) do
    GenServer.start_link(
      __MODULE__,
      %ActivityModel{user: user, subs: subs, moderating: moderating},
      name: {:via, :syn, Gabbler.User.server_name(user)},
      timeout: @server_timeout
    )
  end

  @impl true
  def init(user_info) do
    {:ok, user_info}
  end

  @impl true
  def handle_call(:retrieve_all, _from, %ActivityModel{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:activity_voted, hash}, _from, %ActivityModel{} = state) do
    state = prune_state(state)

    case can_vote?(state, hash) do
      true -> {:reply, true, %{state | votes: [{hash, DateTime.utc_now()} | state.votes]}}
      false -> {:reply, false, state}
    end
  end

  @impl true
  def handle_call({:activity_posted, hash}, _from, %ActivityModel{} = state) do
    state = prune_state(state)
    posts = state.posts

    case can_post?(state) do
      true ->
        posts = [{hash, DateTime.utc_now()} | state.posts]
        {:reply, posts, %{state | posts: posts}}

      false ->
        {:reply, posts, state}
    end
  end

  @impl true
  def handle_call(
        {:activity_subscribed, %{name: room_name}},
        _from,
        %ActivityModel{subs: subscriptions} = state
      ) do
    if Enum.count(subscriptions) < @max_subscriptions do
      subscriptions = [room_name | Enum.filter(subscriptions, fn sub -> sub != room_name end)]

      {:reply, subscriptions, %{state | subs: subscriptions}}
    else
      {:reply, subscriptions, state}
    end
  end

  @impl true
  def handle_call(
        {:activity_unsubscribed, %{name: room_name}},
        _from,
        %ActivityModel{subs: subscriptions} = state
      ) do
    subscriptions = Enum.filter(subscriptions, fn sub -> sub != room_name end)

    {:reply, subscriptions, %{state | subs: subscriptions}}
  end

  @impl true
  def handle_call({:activity_moderating, %{name: name}}, _from, %ActivityModel{moderating: moderating} = state) do
    case can_add_moderate?(state) do
      true ->
        {:reply, true,
         %{
           state
           | moderating: [name | Enum.filter(moderating, fn n -> n != name end)]
         }}

      false ->
        {:reply, false, state}
    end
  end

  @impl true
  def handle_call({:activity_moderate_remove, room_name}, _from, %ActivityModel{moderating: moderating} = state) do
    moderating = Enum.filter(moderating, fn name -> name == room_name end)

    {:reply, moderating, %{state | moderating: moderating}}
  end

  @impl true
  def handle_call({:add_activity, {id, value}}, _from, %ActivityModel{activity: activity} = state) do
    activity = [{id, value} | Enum.take(activity, @max_activity - 1)]

    {:reply, activity, %{state | activity: activity}}
  end

  @impl true
  def handle_call({:remove_activity, id}, _from, %ActivityModel{activity: activity} = state) do
    activity_filtered = Enum.filter(activity, fn {act_id, _} -> act_id != id end)

    {:reply, activity_filtered, %{state | activity: activity_filtered}}
  end

  @impl true
  def handle_call({:can_vote, hash}, _from, %ActivityModel{} = state) do
    state = prune_state(state)

    {:reply, can_vote?(state, hash), state}
  end

  @impl true
  def handle_call(:can_post, _from, %ActivityModel{} = state) do
    state = prune_state(state)

    {:reply, can_post?(state), state}
  end

  @impl true
  def handle_call(:get_posts, _from, %ActivityModel{posts: posts} = state) do
    {:reply, posts, state}
  end

  @impl true
  def handle_call(:get_subscriptions, _from, %ActivityModel{subs: subscriptions} = state) do
    {:reply, subscriptions, state}
  end

  @impl true
  def handle_call(:get_moderating, _from, %ActivityModel{moderating: moderating} = state) do
    {:reply, moderating, state}
  end

  @impl true
  def handle_call({:moderating, %{name: name}}, _from, %ActivityModel{moderating: moderating} = state) do
    {:reply, Enum.any?(moderating, fn m -> m == name end), state}
  end

  @impl true
  def handle_call(:get_activity, _from, %ActivityModel{activity: activity} = state) do
    {:reply, activity, state}
  end

  @impl true
  def handle_call({:update_user, %User{} = user}, _from, %ActivityModel{} = state) do
    {:reply, user, %{state | user: user}}
  end

  @impl true
  def handle_cast({:update_read_receipt, status}, state) do
    {:reply, %{state | read_receipt: status}}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
  defp prune_state(%{votes: votes, posts: posts} = state) do
    curr = DateTime.utc_now()

    state
    |> Map.put(
      :votes,
      Enum.filter(votes, fn {_, time} ->
        DateTime.diff(curr, time, :second) < @vote_limit_expirey * 60 * 60
      end)
    )
    |> Map.put(
      :posts,
      Enum.filter(posts, fn {_, time} ->
        DateTime.diff(curr, time, :second) < @post_limit_expirey * 60 * 60
      end)
    )
  end

  defp can_vote?(%{votes: votes}, hash) do
    Enum.count(votes) < @max_votes &&
      Enum.count(Enum.filter(votes, fn {vote_hash, _} -> vote_hash == hash end)) < 1
  end

  defp can_post?(%{posts: posts}) do
    Enum.count(posts) < @max_posts
  end

  defp can_add_moderate?(%{moderating: moderating}) do
    Enum.count(moderating) < @max_moderating
  end
end
