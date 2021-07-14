if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.Repo do
    use Ecto.Repo,
      otp_app: :ecto_explorer,
      adapter: Ecto.Adapters.SQLite3
  end
end
