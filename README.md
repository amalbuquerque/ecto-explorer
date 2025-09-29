# EctoExplorer

A small utility that uses metaprogramming to provide a neat `~>/2` macro to explore Ecto associations without having to `Repo.preload/2` all the time.

Use it like this:

```
iex> use EctoExplorer, repo: EctoExplorer.Repo
EctoExplorer

iex> f = Repo.get_by(Flag, colors: "YBR")
%EctoExplorer.Schemas.Flag{...}

iex> f~>country.addresses[0].postal_code
"postal_code_ECU_1"

iex> f~>country.addresses[-1].postal_code
"postal_code_ECU_6"
```

## Next steps

- Allow index access to get specific structs by a specific criteria, e.g. `flag~>country.addresses[id=123]` or `flag~>country.addresses[city="Lisbon"]` ✅
- Return a single record if the preloaded list only has a single element, or nil if the list is empty
- Allow the index access (e.g. `[2]`) to be applied after the `where` access (e.g. `[city="Lisbon"]`)
- Allow an actual schema to be passed on the left-hand side (e.g. `Country~>[code="ECU"]`)

## Installation

The package can be installed by adding `ecto_explorer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_explorer, "~> 0.5.0", only: [:dev, :test]}
  ]
end
```

ℹ️  Notice that we're only adding it as a dependency for `:dev` and `:test` Mix environments.

🚨 Please don't use this in Production! This library is a convenience to quickly navigate
complex domain models, it shouldn't ever be considered as a way to avoid thinking about
how you `Repo.preload/2` your associations.

Docs can be found at [https://hexdocs.pm/ecto_explorer](https://hexdocs.pm/ecto_explorer).
