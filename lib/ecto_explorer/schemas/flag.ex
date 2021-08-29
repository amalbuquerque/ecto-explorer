if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.Schemas.Flag do
    use Ecto.Schema

    import Ecto.Changeset

    alias EctoExplorer.Schemas.Country

    schema "flags" do
      field(:colors, :string)
      field(:orientation, :string)
      belongs_to(:country, Country)
    end

    def changeset(flag, attrs) do
      flag
      |> cast(attrs, [:colors, :orientation, :country_id])
      |> validate_required([:colors, :country_id])
    end
  end
end
