defmodule Gabbler.Story.StoryState do
  @moduledoc """
  The struct that holds running status of a post
  """
  alias GabblerData.Post
  alias GabblerData.PostMeta
  alias Gabbler.Accounts.User

  @derive [Jason.Encoder]
  defstruct hash: nil, user: %User{}, post: %Post{}, post_meta: %PostMeta{}, imgs: [], editors: []
end