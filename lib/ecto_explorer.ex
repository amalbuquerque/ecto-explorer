defmodule EctoExplorer do
  @moduledoc """
  Documentation for `EctoExplorer`.
  """

  require Logger

  alias EctoExplorer.Resolver

  @repo_agent_name EctoExplorer.CachedRepo

  defmacro __using__(repo: repo) do
    if Mix.env() not in [:dev, :test] do
      IO.puts(
        "⚠️ You're using EctoExplorer on the `#{Mix.env()}` environment.\n⚠️ EctoExplorer isn't in any way optimized for Production usage, and forces the preload of each association. Use with care!"
      )
    end

    {:ok, _pid} =
      repo
      |> Macro.expand(__ENV__)
      |> maybe_start_repo_agent()

    quote do
      import unquote(__MODULE__)
    end
  end

  @doc false
  def cached_repo do
    Agent.get(@repo_agent_name, & &1)
  end

  @doc false
  def check_cached_repo! do
    case Process.whereis(@repo_agent_name) do
      nil ->
        raise "To use the `EctoExplorer.~>/2` macro you need to `use EctoExplorer, repo: <your-repo-module>` first."

      _ ->
        :ok
    end
  end

  def maybe_start_repo_agent(repo) do
    case Process.whereis(@repo_agent_name) do
      nil ->
        Agent.start(fn -> repo end, name: @repo_agent_name)

      pid ->
        {:ok, pid}
    end
  end

  @doc """
  This macro allows you to easily explore Ecto associations
  in your shell, without having to `Repo.preload/2` each time
  you want to explore the next association.

  You need to `use EctoExplorer, repo: <your-ecto-repo>` before
  you can use the `~>/2` macro.

  Example:
  ```
  iex> author = Repo.get(Author, 1)
  %Author{id: 1}

  iex> author~>address.city
  "Lisbon"

  iex> author~>posts[0].title
  "My first blog post"
  ```
  """
  defmacro left ~> right do
    check_cached_repo!()

    quoted_steps =
      right
      |> Resolver.steps()
      |> Macro.escape()

    quote bind_quoted: [left: left, steps: quoted_steps] do
      steps
      |> Enum.reduce(left, fn step, acc ->
        EctoExplorer.Resolver.resolve(acc, step)
      end)
    end
  end
end
