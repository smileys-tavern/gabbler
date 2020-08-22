defmodule Gabbler.Story.Image do
  @derive [Jason.Encoder]
  defstruct id: nil, url: nil, thumb: nil, size: 0
end