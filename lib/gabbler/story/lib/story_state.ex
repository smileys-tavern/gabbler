defmodule Gabbler.Story.StoryState do
  @moduledoc """
  The struct that holds running status of a post
  """
  alias GabblerData.Post
  alias Gabbler.Accounts.User

  defstruct hash: nil, user: %User{}, post: %Post{}, imgs: [], thumb: nil, editors: []
end