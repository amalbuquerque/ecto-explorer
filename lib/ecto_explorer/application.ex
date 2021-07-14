if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.Application do
    @moduledoc false

    use Application

    def start(_type, _args) do
      IO.puts("Starting EctoExplorer supervision tree. Environment: #{Mix.env()}")

      Application.put_env(:ecto_explorer, :ecto_repos, [EctoExplorer.Repo])

      Application.put_env(:ecto_explorer, EctoExplorer.Repo,
        database: "/tmp/ecto_explorer_#{timestamp()}.db"
      )

      children = [
        EctoExplorer.Repo
      ]

      opts = [strategy: :one_for_one, name: Tiger.Supervisor]

      Supervisor.start_link(children, opts)
    end

    def timestamp do
      DateTime.utc_now()
      |> to_string()
      |> String.replace(":", "")
      |> String.replace(".", "")
      |> String.replace("-", "")
      |> String.replace(" ", "")
    end
  end
end
