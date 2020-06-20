defmodule Gabbler.Post.PostState do
  @moduledoc """
  The struct that holds running status of a post
  """
  alias GabblerData.Post

  defstruct post: %Post{}
end