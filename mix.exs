defmodule Gabbler.MixProject do
  use Mix.Project

  def project do
    [
      app: :gabbler,
      version: "0.10.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Gabbler.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 2.0"},
      # PHX
      {:phoenix, "~> 1.5.1"},
      {:phoenix_live_view, "~> 0.12.0"},
      {:floki, ">= 0.0.0", only: :test},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.2.0"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.17"},
      {:jason, "~> 1.0", override: true},
      {:plug_cowboy, "~> 2.1"},
      # RELEASE
      {:distillery, "~> 2.1"},
      {:edeliver, "~> 1.7"},
      {:phx_gen_auth, "~> 0.2.0", only: [:dev], runtime: false},
      # GABBLER DEPENDENCY
      {:timex, "~> 3.6"},
      {:thumbnex, "~> 0.3.1"},
      {:html_sanitize_ex, "~> 1.3"},
      {:cloudex, "~> 1.3"},
      {:bamboo, "~> 1.3"},
      {:recaptcha, "~> 3.0"},
      {:syn, "~> 2.1"},
      {:earmark, "~> 1.4"},
      {:simplestatex, "~> 0.3.0"},
      {:quantum, "~> 2.3"},
      {:httpotion, "~> 3.1.0"},
      {:nebulex, "~> 1.2.2"},
      {:jchash, git: "https://github.com/nikolaik/jchash.git", branch: "fix/otp23", app: false}
      | env_deps(Mix.env())
    ]
  end

  defp env_deps(:dev) do
    [
      {:gabbler_data, path: "../gabbler_data", env: :dev}
    ]
  end

  defp env_deps(env) when env in [:prod] do
    [
      {:gabbler_data, git: "https://github.com/smileys-tavern/gabbler_data", env: Mix.env()}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "cmd npm install --prefix assets"]
    ]
  end
end
