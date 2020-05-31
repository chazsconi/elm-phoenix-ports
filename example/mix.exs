defmodule ElmPhoenix.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elm_phoenix,
      version: "0.0.1",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {ElmPhoenix.Application, []}, extra_applications: [:logger, :runtime_tools]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.5.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_html, "~> 2.9"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.13"},
      {:plug_cowboy, "~> 2.2"},
      {:plug, "~> 1.7"},
      {:jason, "~> 1.0"}
    ]
  end
end
