defmodule EctoExplorer.Resolver do
  @moduledoc """
  Translates the `x~><query_expression>` quoted expression into a set of steps,
  and then _resolves_ each step to get the resulting value.

  To resolve a step means getting the resulting value after applying the step.

  E.g. in `country~>addresses[3]`, there are two steps, `addresses` and `[3]`.

  The first `addresses` step will return all addresses of the `country` struct,
  whereas the `[3]` step will return the 4th (0-index based) address.
  """

  defmodule Step do
    defstruct [:key, :index, :where]
  end

  require Logger

  alias EctoExplorer.Preloader

  @doc false
  def resolve(current, %Step{} = step) do
    with {:ok, step} <- validate_step(current, step) do
      _resolve(current, step)
    else
      {:error, :current_is_nil} ->
        nil

      _error ->
        raise ArgumentError, "Invalid step #{inspect(step)} when evaluating #{inspect(current)}"
    end
  end

  @doc false
  def _resolve(current, %Step{key: step_key, index: nil} = step) do
    case Map.get(current, step_key) do
      %Ecto.Association.NotLoaded{} ->
        current
        |> Preloader.preload(step_key)
        |> _resolve(step)

      nil ->
        Logger.warning("[Current: #{inspect(current)}] Step '#{step_key}' resolved to `nil`")
        nil

      value ->
        value
    end
  end

  @doc false
  def _resolve(current, %Step{key: step_key, index: index} = step) when is_integer(index) do
    case Map.get(current, step_key) do
      %Ecto.Association.NotLoaded{} ->
        current
        |> Preloader.preload(step_key)
        |> _resolve(step)

      value when is_list(value) ->
        Enum.at(value, index)
    end
  end

  @doc false
  def steps(quoted_right) do
    {_node,
     %{
       visited: _visited,
       expected_index_steps: expected_index_steps,
       steps: steps
     }} = _steps(quoted_right)

    steps_with_index = Enum.count(steps, & &1.index)

    steps = Enum.reverse(steps)

    if expected_index_steps != steps_with_index do
      raise ArgumentError,
            "Expected #{expected_index_steps} steps with index, only got #{steps_with_index}. Right-hand expression: #{Macro.to_string(quoted_right)}, steps: #{inspect(steps)}"
    end

    steps
  end

  @doc false
  def _steps(quoted_right) do
    quoted_right
    |> Macro.postwalk(%{visited: [], steps: [], expected_index_steps: 0}, &process_node/2)
  end

  # :get is the current node, and Access was the previous
  # so we know there will be one step with index
  defp process_node(:get, %{visited: [Access | _]} = acc) do
    acc =
      acc
      |> accumulate_node(:get)
      |> increment_expected_index_steps()

    {:get, acc}
  end

  defp process_node(Access, acc) do
    acc = accumulate_node(acc, Access)

    {Access, acc}
  end

  defp process_node({:-, _, _} = node, acc) do
    acc =
      acc
      |> accumulate_node(node)
      |> negate_last_step_index()

    {node, acc}
  end

  defp process_node({:., _, _} = node, acc) do
    acc = accumulate_node(acc, node)

    {node, acc}
  end

  defp process_node({:=, _, [{clause_key, _, _}, clause_value]} = node, acc) do
    IO.inspect(node, label: ":= NODE")
    IO.inspect(acc, label: "ACC")

    acc =
      acc
      |> accumulate_node(node)
      |> update_last_step_where(clause_key, clause_value)

    {node, acc}
  end

  defp process_node({first_step, _, _} = node, acc) when is_atom(first_step) do
    acc = accumulate_node(acc, node, %Step{key: first_step})

    {node, acc}
  end

  defp process_node(step, acc) when is_atom(step) do
    acc = accumulate_node(acc, step, %Step{key: step})

    {step, acc}
  end

  defp process_node(index, acc) when is_integer(index) do
    acc =
      acc
      |> accumulate_node(index)
      |> update_last_step_index(index)

    {index, acc}
  end

  defp process_node(node, acc) do
    acc = accumulate_node(acc, node)

    {node, acc}
  end

  defp negate_last_step_index(%{steps: [last_step | rest_steps]} = acc) do
    updated_step = %{last_step | index: -last_step.index}

    %{acc | steps: [updated_step | rest_steps]}
  end

  defp update_last_step_where(%{steps: [last_step | rest_steps]} = acc, clause_key, clause_value) do
    updated_step = %{last_step | where: [{clause_key, clause_value}]}

    %{acc | steps: [updated_step | rest_steps]}
  end

  defp update_last_step_index(%{steps: [last_step | rest_steps]} = acc, index) do
    updated_step = %{last_step | index: index}

    %{acc | steps: [updated_step | rest_steps]}
  end

  defp increment_expected_index_steps(%{expected_index_steps: n} = acc) do
    %{acc | expected_index_steps: n + 1}
  end

  defp accumulate_node(%{visited: visited} = acc, node) do
    %{acc | visited: [node | visited]}
  end

  defp accumulate_node(
         %{
           visited: visited,
           steps: steps
         } = acc,
         node,
         %Step{} = step
       ) do
    %{acc | visited: [node | visited], steps: [step | steps]}
  end

  def validate_step(current, %Step{key: step_key} = step) when is_map(current) do
    case step_key in Map.keys(current) do
      true -> {:ok, step}
      _ -> {:error, :invalid_step}
    end
  end

  def validate_step(nil, _step) do
    {:error, :current_is_nil}
  end

  def validate_step(_current, _step) do
    {:error, :current_not_struct}
  end
end
