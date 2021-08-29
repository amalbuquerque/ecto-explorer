if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.Schemas.Currency do
    use Ecto.Schema

    import Ecto.Changeset

    alias EctoExplorer.Schemas.Country

    schema "currencies" do
      field(:code, :string)
      field(:symbol, :string)
      field(:name, :string)
      many_to_many(:countries, Country, join_through: "countries_currencies")
    end

    def changeset(currency, attrs) do
      currency
      |> cast(attrs, [:code, :symbol, :name])
      |> validate_required([:code, :symbol])
    end
  end
end
