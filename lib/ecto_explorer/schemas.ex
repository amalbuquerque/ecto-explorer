if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.Schemas do
    defmodule Flag do
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

    defmodule Currency do
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

    defmodule Address do
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

    defmodule Country do
      use Ecto.Schema

      import Ecto.Changeset

      alias EctoExplorer.Schemas.{Address, Flag, Currency}

      schema "countries" do
        field(:name, :string)
        field(:code, :string)
        field(:population, :integer)
        has_one(:flag, Flag)
        many_to_many(:currencies, Currency, join_through: "countries_currencies")
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
end
