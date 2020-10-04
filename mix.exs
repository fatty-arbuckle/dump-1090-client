defmodule Dump1090Client.MixProject do
  use Mix.Project

  def project do
    [
      app: :dump_1090_client,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
      # mod: {Dump1090Client.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:adsb_parser, git: "https://github.com/fatty-arbuckle/adsb-parser.git"},
      # {:adsb_parser, path: "../adsb-parser"},
      {:tortoise, "~> 0.9"},
      {:json, "~> 1.3"}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
