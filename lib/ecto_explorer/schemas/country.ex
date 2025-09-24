if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.Schemas.Country do
    use Ecto.Schema

    import Ecto.Changeset

    alias EctoExplorer.Schemas.Address
    alias EctoExplorer.Schemas.Currency
    alias EctoExplorer.Schemas.Flag

    schema "countries" do
      field(:name, :string)
      field(:code, :string)
      field(:population, :integer)
      has_one(:flag, Flag)
      many_to_many(:currencies, Currency, join_through: "countries_currencies")
      # we can set the preload_order here,
      # but not dynamically in runtime
      # has_many(:addresses, Address, preload_order: [desc: :id])
      has_many(:addresses, Address)
    end

    def changeset(country, attrs) do
      country
      |> cast(attrs, [:name, :code, :population])
      |> unique_constraint(:name)
      |> unique_constraint(:code)
    end
  end
end
