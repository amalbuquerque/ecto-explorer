if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.Schemas.Address do
    use Ecto.Schema

    import Ecto.Changeset

    alias EctoExplorer.Schemas.Country

    schema "addresses" do
      field(:first_line, :string)
      field(:postal_code, :string)
      field(:city, :string)
      belongs_to(:country, Country)
    end

    def changeset(address, attrs) do
      address
      |> cast(attrs, [:first_line, :postal_code, :city, :country_id])
      |> validate_required([:first_line, :postal_code, :city, :country_id])
    end
  end
end
