defmodule WebSockex.Mixfile do
  use Mix.Project

  @source_url "https://github.com/Azolo/websockex"
  @version "0.4.3"

  def project do
    [
      app: :websockex,
      name: "WebSockex",
      version: @version,
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      deps: deps(),
      docs: docs(),
      dialyzer: [
        flags: [:underspecs, :unknown, :unmatched_returns],
        plt_add_apps: [:mix, :iex, :ex_unit, :ranch, :plug, :websockex, :cowboy]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ['lib', 'test/support']
  defp elixirc_paths(_), do: ['lib']

  def application do
    applications = [:logger, :ssl, :crypto] ++ applications(otp_release())
    [applications: applications, mod: {WebSockex.Application, []}]
  end

  defp applications(otp_release) when otp_release >= 21 do
    [:telemetry]
  end

  defp applications(_), do: []

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:cowboy, "~> 2.5"},
      {:plug, "~> 1.7"},
      {:plug_cowboy, "~> 2.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ] ++ optional_deps(otp_release())
  end

  defp optional_deps(otp_release) when otp_release >= 21 do
    [{:telemetry, "~> 1.0"}]
  end

  defp optional_deps(_), do: []

  defp package do
    [
      description: "An Elixir WebSocket client",
      licenses: ["MIT"],
      maintainers: ["Justin Baker"],
      links: %{
        "Changelog" => "https://hexdocs.pm/websockex/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "#{@version}"
    ]
  end

  defp otp_release do
    :erlang.system_info(:otp_release) |> to_string() |> String.to_integer()
  end
end
