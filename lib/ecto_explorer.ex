defmodule EctoExplorer do
  @moduledoc """
  Documentation for `EctoExplorer`.
  """

  require Logger

  @repo_agent_name EctoExplorer.CachedRepo

  defmacro __using__(repo: repo) do
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

  def maybe_start_repo_agent(repo) do
    case Process.whereis(@repo_agent_name) do
      nil ->
        Agent.start(fn -> repo end, name: @repo_agent_name)

      pid ->
        {:ok, pid}
    end
  end

  defmacro left ~> right do
    Logger.debug("LEFT: #{inspect(left)}")
    Logger.debug("RIGHT: #{inspect(right)}")

    quote bind_quoted: [left: left, right: right] do
      inspect(left) <> "\nZZ\n" <> inspect(right)
    end
  end
end
