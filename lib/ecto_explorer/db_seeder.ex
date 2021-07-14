if Mix.env() in [:dev, :test] do
  defmodule EctoExplorer.DbSeeder do
    alias EctoExplorer.Repo
    alias EctoExplorer.Schemas.{Flag, Currency, Country, Address}

    @countries_table """
      CREATE TABLE countries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        population INTEGER NULL
      );
    """

    @flags_table """
      CREATE TABLE flags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        colors TEXT NOT NULL,
        orientation TEXT NULL,
        country_id INTEGER,
        FOREIGN KEY(country_id) REFERENCES countries(id)
      );
    """

    @currencies_table """
      CREATE TABLE currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL,
        symbol TEXT NOT NULL,
        name TEXT NULL
      );
    """

    @countries_currencies_table """
      CREATE TABLE countries_currencies (
        country_id INTEGER,
        currency_id INTEGER,
        FOREIGN KEY(country_id) REFERENCES countries(id),
        FOREIGN KEY(currency_id) REFERENCES currencies(id)
      );
    """

    @addresses_table """
      CREATE TABLE addresses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_line TEXT NOT NULL,
        postal_code TEXT NOT NULL,
        city TEXT NOT NULL,
        country_id INTEGER,
        FOREIGN KEY(country_id) REFERENCES countries(id)
      );
    """

    def create_tables do
      [
        @countries_table,
        @flags_table,
        @currencies_table,
        @countries_currencies_table,
        @addresses_table
      ]
      |> Enum.map(&Repo.query/1)
    end

    def fill_tables do
      # TODO:
      # create country USA, ECU (uses USD), GBR, PRT, ESP
      # create currency USD, GBP, EUR
      #
      # create flag for some countries (let GBR without flag)
      #
      # create addresses for some countries (let USA without addresses)
    end

    def insert_country(name, code, population) do
      %Country{}
      |> Country.changeset(%{name: name, code: code, population: population})
      |> Repo.insert()
    end

    def insert_flag(colors, orientation, country_id) do
      %Flag{}
      |> Flag.changeset(%{colors: colors, orientation: orientation, country_id: country_id})
      |> Repo.insert()
    end

    def insert_address(first_line, postal_code, city, country_id) do
      %Address{}
      |> Address.changeset(%{
        first_line: first_line,
        postal_code: postal_code,
        city: city,
        country_id: country_id
      })
      |> Repo.insert()
    end

    def insert_currency(code, symbol, name) do
      %Currency{}
      |> Currency.changeset(%{
        code: code,
        symbol: symbol,
        name: name
      })
      |> Repo.insert()
    end

    def associate_country_with_currency(%Country{} = country, %Currency{} = currency) do
      country = Repo.preload(country, :currencies)

      country
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:currencies, [currency | country.currencies])
      |> Repo.update()
    end
  end
end
