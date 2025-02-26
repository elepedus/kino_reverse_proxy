defmodule KinoReverseProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :kino_reverse_proxy,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bandit, "~> 1.2"},
      {:reverse_proxy_plug, "~> 2.3"},
      {:kino, "~> 0.12"},
      {:httpoison, "~> 2.0"},
      {:meck, "~> 0.9", only: :test}
    ]
  end
end
