defmodule EctoExplorer.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_explorer,
      version: "0.5.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/amalbuquerque/ecto-explorer",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    case Mix.env() do
      env when env in [:dev, :test] ->
        [
          mod: {EctoExplorer.Application, []},
          extra_applications: [:logger]
        ]

      _ ->
        [
          extra_applications: [:logger]
        ]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.5"},
      {:ecto_sqlite3, "~> 0.5.6", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp package() do
    [
      description: "Library to easily navigate Ecto associations",
      licenses: ["MIT"],
      maintainers: ["André Albuquerque"],
      links: %{
        Github: "https://github.com/amalbuquerque/ecto-explorer"
      }
    ]
  end
end
