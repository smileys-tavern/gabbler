defmodule Gabbler.TagTracker.TopContent do
  @derive [Jason.Encoder]
  defstruct type: nil, url: nil, ext_url: nil, imgs: [], thumbs: [], desc: nil, long: nil
end
