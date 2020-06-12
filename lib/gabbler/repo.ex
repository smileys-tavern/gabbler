defmodule Gabbler.Repo do
  use Ecto.Repo,
    otp_app: :gabbler_data,
    adapter: Ecto.Adapters.Postgres
end