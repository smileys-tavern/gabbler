defmodule Gabbler.Cache do
  use Nebulex.Cache,
    otp_app: :gabbler,
    adapter: Nebulex.Adapters.Local

  defmodule LocalCache do
    use Nebulex.Cache,
      otp_app: :gabbler,
      adapter: Nebulex.Adapters.Local
  end
end
