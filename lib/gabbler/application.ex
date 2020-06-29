defmodule Gabbler.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Initialize nebulex, distributed cache
    :ok = setup_cluster()

    children = [
      GabblerData.Repo,
      GabblerWeb.Telemetry,
      {Phoenix.PubSub, name: Gabbler.PubSub},
      GabblerWeb.Endpoint,
      {Gabbler.User.Application, strategy: :one_for_one, name: :user_server},
      {Gabbler.Room.Application, strategy: :one_for_one, name: :room_server},
      {Gabbler.Post.Application, strategy: :one_for_one, name: :post_server},
      Gabbler.TagTracker.Application,
      worker(Gabbler.Scheduler, []),
      Gabbler.Cache,
      Gabbler.Cache.LocalCache,
      GabblerWeb.Presence
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Gabbler.Supervisor)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GabblerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # PRIVATE FUNCTIONS
  ###################
  defp setup_cluster() do
    :gabbler
    |> Application.get_env(:nodes, [])
    |> Enum.each(&:net_adm.ping/1)
  end
end
