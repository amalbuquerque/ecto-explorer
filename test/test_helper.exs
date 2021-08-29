IO.puts("[TestHelper] Creating and filling tables")

# create tables and fill seed data needed for tests
EctoExplorer.DbSeeder.create_tables()
EctoExplorer.DbSeeder.fill_tables()

ExUnit.start()
