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

    def drop_tables do
      [
        "countries",
        "flags",
        "currencies",
        "countries_currencies",
        "addresses"
      ]
      |> Enum.reverse()
      |> Enum.map(&Repo.query("DROP TABLE #{&1}"))
    end

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
      {:ok, usa_country} = insert_country("United States", "USA", 5)
      {:ok, ecu_country} = insert_country("Ecuador", "ECU", 6)
      {:ok, gbr_country} = insert_country("Great Britain", "GBR", 7)
      {:ok, prt_country} = insert_country("Portugal", "PRT", 8)
      {:ok, esp_country} = insert_country("Spain", "ESP", 9)

      # create currency USD, GBP, EUR
      {:ok, usd_currency} = insert_currency("USD", "$", "US Dollar")
      {:ok, suc_currency} = insert_currency("SUC", "Suc", "Ecuador Sucre")
      {:ok, gbp_currency} = insert_currency("GBP", "Pound", "Great Britain Pound")
      {:ok, eur_currency} = insert_currency("EUR", "Eur", "Euro")

      # associate currencies with countries
      {:ok, %Country{}} = associate_country_with_currency(prt_country, eur_currency)
      {:ok, %Country{}} = associate_country_with_currency(esp_country, eur_currency)

      {:ok, %Country{}} = associate_country_with_currency(usa_country, usd_currency)
      {:ok, %Country{}} = associate_country_with_currency(ecu_country, usd_currency)

      {:ok, %Country{}} = associate_country_with_currency(ecu_country, suc_currency)

      {:ok, %Country{}} = associate_country_with_currency(gbr_country, gbp_currency)

      # create flags (GBR without flag)
      {:ok, _usa_flag} = insert_flag("RBW", "horizontal", usa_country.id)
      {:ok, _ecu_flag} = insert_flag("YBR", "horizontal", ecu_country.id)
      # {:ok, _gbr_flag} = insert_flag("RBW", "union jack", gbr_country.id)
      {:ok, _prt_flag} = insert_flag("GRY", "vertical", prt_country.id)
      {:ok, _esp_flag} = insert_flag("RYR", "horizontal", esp_country.id)

      # create addresses for some countries (USA without addresses)
      {:ok, _ecu_addresses} = insert_x_addresses(ecu_country, 6)
      {:ok, _prt_addresses} = insert_x_addresses(prt_country, 5)
      {:ok, _esp_addresses} = insert_x_addresses(esp_country, 4)
      {:ok, _gbr_addresses} = insert_x_addresses(gbr_country, 3)
    end

    defp insert_x_addresses(country, x) do
      1..x
      |> Enum.reduce_while([], fn x, acc ->
        suffix = "#{country.code}_#{x}"

        case insert_address(
               "first_line_#{suffix}",
               "postal_code_#{suffix}",
               "city_#{suffix}",
               country.id
             ) do
          {:ok, address} ->
            {:cont, [address | acc]}

          error ->
            {:halt, error}
        end
      end)
      |> case do
        [%Address{} | _] = addresses ->
          {:ok, addresses}

        error ->
          error
      end
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
