defmodule Gabbler.ReleaseTasks do
  @moduledoc """
  Run tasks related to new or migrating systems
  """
  import Ecto.Query, warn: false
  alias GabblerData.Repo

  @doc """
  Migrate Database
  """
  def migrate([]) do
    start_app()

    path = Application.app_dir(:gabbler_data, "priv/repo/migrations")

    Ecto.Migrator.run(Repo, path, :up, all: true)

    stop_app()
  end

  defp start_app() do
    IO.puts "Starting dependencies.."
    # Start apps necessary for executing migrations
    #Enum.each(@start_apps, &Application.ensure_all_started/1)

    {:ok, _} = Application.ensure_all_started(:gabbler)

    _ = Application.ensure_all_started(:timex)

    # Start the Repo(s) for myapp
    #IO.puts "Starting repos.."
    #Enum.each(repos(), &(&1.start_link(pool_size: 1)))
  end

  defp stop_app() do
    :init.stop()
  end
end