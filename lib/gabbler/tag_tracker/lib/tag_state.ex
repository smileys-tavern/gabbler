defmodule Gabbler.TagTracker.TagState do
  @moduledoc """
  A struct representing the state of recent tagging activity across the site as maintained per server

  Tags: 
    - Keyed by tag, contains the actual post information summarized.
    - Size constrained by ejections from queue
    - Votes are added in small queues periodically by a timed process
    - Holds the total score and score stack for each tag as well
    - Score stack tracks and ejects latest vote totals

  Queue: 
    - Tracks the active tags as the most recent unique tags added (check Map to see if added)
    - As queue is ejected per size constraints, ejects entries from Posts map

  Trending:
    - Contains a list of trending tags
    - Periodically updated via a sorting call
  """
  @derive [Jason.Encoder]
  defstruct tags: %{}, queue: [], trending: []
end
