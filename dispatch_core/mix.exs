defmodule DispatchCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :dispatch_core,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: ["lib"],
      # erlc_paths tells mix to also compile the raw .erl module in src/ -
      # this is what makes nearest_driver.erl part of the same in-process
      # BEAM application as the rest of the Elixir code.
      erlc_paths: ["src"],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {DispatchCore.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"}
    ]
  end
end
