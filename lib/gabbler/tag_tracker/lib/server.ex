defmodule Gabbler.TagTracker.Server do
  use GenServer

  alias Gabbler.TagTracker
  alias Gabbler.TagTracker.TagState
  alias GabblerData.Post

  # Characters
  @rule_longest_title 140
  # Characters
  @rule_longest_body 140
  # Amount of items taken in a request for random tags
  @take_x_random 3

  def start_link(_) do
    GenServer.start_link(__MODULE__, %TagState{},
      name: {:via, :syn, Gabbler.TagTracker.server_name()}
    )
  end

  ## Callbacks

  @impl true
  def init(tag_state) do
    {:ok, tag_state}
  end

  @impl true
  def handle_cast(
        {:get, {:trending, client_channel}},
        %TagState{trending: trending, tags: tags} = state
      ) do
    Enum.reduce(trending, [], fn tag, acc ->
      {_, _, posts} = Map.get(tags, tag)

      acc ++ posts
    end)
    |> broadcast_to_client(client_channel)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:get, {:random, client_channel}}, %TagState{tags: tags, queue: queue} = state) do
    Enum.reduce(Enum.take_random(queue, @take_x_random), [], fn tag, acc ->
      {_, _, posts} = Map.get(tags, tag)

      acc ++ posts
    end)
    |> broadcast_to_client(client_channel)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:get, {tag, client_channel}}, %{tags: tags} = state) do
    case Map.get(tags, tag) do
      nil ->
        {:noreply, state}

      {_, _, posts} ->
        broadcast_to_client(posts, client_channel)

        {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:add, {tag, post}}, %TagState{tags: tags, queue: queue} = state) do
    post = format_post(post)

    case Map.get(tags, tag) do
      nil ->
        tags = Map.put(tags, tag, {1, [{1, DateTime.to_unix(DateTime.utc_now())}], [post]})

        broadcast_to_client([post], TagTracker.tag_channel(tag))

        {:noreply, %{state | tags: tags, queue: [tag | queue]}}

      {score, [{latest_score, unixtime} | t], posts} ->
        tags =
          Map.put(
            tags,
            tag,
            {score, [{latest_score + 1, unixtime} | t], add_to_posts(post, posts)}
          )

        broadcast_to_client([post], TagTracker.tag_channel(tag))

        {:noreply, %{state | :tags => tags}}
    end
  end

  @impl true
  def handle_cast({:update, {tag, add_score}}, %TagState{tags: tags} = state) do
    case Map.get(tags, tag) do
      nil ->
        {:noreply, state}

      {score, [{latest_score, unixtime} | t], posts} ->
        tags = Map.put(tags, tag, {score, [{latest_score + add_score, unixtime} | t], posts})

        {:noreply, %{state | tags: tags}}
    end
  end

  @impl true
  def handle_cast(:sort, %TagState{tags: tags, queue: queue} = state) do
    curr_unix = DateTime.to_unix(DateTime.utc_now())

    sorted_tags =
      Enum.sort(queue, fn tag_a, tag_b ->
        {score_a, _, _} = Map.get(tags, tag_a)
        {score_b, _, _} = Map.get(tags, tag_b)

        score_a > score_b
      end)

    trending_tags = Enum.slice(sorted_tags, 0..Application.get_env(:gabbler, :tags_max_trending))

    # Split out the weak trending from the strong
    {tag_remain, texit} =
      Enum.uniq(queue)
      |> Enum.split(Application.get_env(:gabbler, :tags_max_per_server))

    # Cull tags and update scoring windows
    tags =
      cull_tags(tags, texit)
      |> update_tag_score_lists(curr_unix)

    {:noreply, %{state | trending: trending_tags, queue: tag_remain, tags: tags}}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}

  # PRIVATE FUNCTIONS
  ###################
  defp add_to_posts(post, posts) do
    [format_post(post) | posts]
    |> Enum.slice(0..Application.get_env(:gabbler, :tags_max_posts_per_topic, 5))
  end

  defp format_post(%Post{title: title, body: body} = post) do
    post
    |> Map.put(:title, String.slice(title, 0..@rule_longest_title))
    |> Map.put(:body, String.slice(body, 0..@rule_longest_body))
  end

  defp cull_tags(tags, []), do: tags

  defp cull_tags(tags, [tag | t]), do: cull_tags(Map.delete(tags, tag), t)

  defp update_tag_score_lists(tags, curr_unix) do
    Enum.reduce(tags, %{}, fn {tag, {_, score_list, posts}}, acc ->
      case cull_tag_scores(score_list, curr_unix) do
        [] ->
          # Tag is aged out
          acc

        remain_scores ->
          score_tuple =
            {get_total_tag_score(remain_scores),
             add_tag_score_timeslice(remain_scores, curr_unix), posts}

          Map.put(acc, tag, score_tuple)
      end
    end)
  end

  defp cull_tag_scores(scores, curr_unix) do
    cull_tag_scores(scores, curr_unix, [])
  end

  defp cull_tag_scores([], _, acc), do: Enum.reverse(acc)

  defp cull_tag_scores([{score, unix} | t], curr_unix, acc) do
    if curr_unix - unix < Application.get_env(:gabbler, :tags_score_duration, 24) * 60 * 60 do
      cull_tag_scores(t, curr_unix, [{score, unix} | acc])
    else
      # Tag scores operate as stack; only older times remain
      cull_tag_scores([], curr_unix, acc)
    end
  end

  defp add_tag_score_timeslice([{_, unix} = score | t], curr_unix) do
    # Score older than an hour old
    if curr_unix - unix < 360 do
      [score | t]
    else
      [{0, curr_unix}, score | t]
    end
  end

  defp get_total_tag_score(tag_scores),
    do: Enum.reduce(tag_scores, 0, fn {score, _}, acc -> acc + score end)

  defp broadcast_to_client(posts, client_channel) do
    tag_list = Enum.slice(posts, 0..Application.get_env(:gabbler, :tags_max_posts_client, 10))

    GabblerWeb.Endpoint.broadcast(client_channel, "tag_list", %{list: tag_list})
  end
end
