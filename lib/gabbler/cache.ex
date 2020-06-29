defmodule Gabbler.Cache do
  use Nebulex.Cache,
    otp_app: :gabbler,
    adapter: Nebulex.Adapters.Local

  defmodule LocalCache do
    use Nebulex.Cache,
      otp_app: :gabbler,
      adapter: Nebulex.Adapters.Local
  end

  def set_if(nil, _, _), do: nil
  def set_if(false, _, _), do: false
  def set_if(value, key, opts), do: set(key, value, opts)
end
