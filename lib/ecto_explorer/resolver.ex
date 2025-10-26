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
        |> Preloader.preload(step)
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
        |> Preloader.preload(step)
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

    # both index and where steps use the `[...]` construct
    steps_with_index =
      steps
      |> Enum.map(fn step ->
        cond do
          is_integer(step.index) ->
            1

          is_list(step.where) ->
            length(step.where)

          true ->
            0
        end
      end)
      |> Enum.sum()

    steps = Enum.reverse(steps)

    if expected_index_steps != steps_with_index do
      raise ArgumentError,
            "Expected #{expected_index_steps} steps with index/where, only got #{steps_with_index}. Right-hand expression: #{Macro.to_string(quoted_right)}, steps: #{inspect(steps)}"
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
  defp process_node(:get = node, %{visited: [Access | _]} = acc) do
    debug_process_node(:before, node, acc)

    acc =
      acc
      |> accumulate_node(:get)
      |> increment_expected_index_steps()

    debug_process_node(:after, node, acc)

    {:get, acc}
  end

  defp process_node(Access = node, acc) do
    debug_process_node(:before, node, acc)

    acc = accumulate_node(acc, Access)

    debug_process_node(:after, node, acc)

    {Access, acc}
  end

  defp process_node({:-, _, _} = node, acc) do
    debug_process_node(:before, node, acc)

    acc =
      acc
      |> accumulate_node(node)
      |> negate_last_step_index()

    debug_process_node(:after, node, acc)

    {node, acc}
  end

  defp process_node({:., _, _} = node, acc) do
    acc = accumulate_node(acc, node)

    {node, acc}
  end

  defp process_node({:=, _, [{clause_key, _, _}, clause_value]} = node, acc) do
    debug_process_node(:before, node, acc)

    acc =
      acc
      |> accumulate_node(node)
      |> update_last_step_where(clause_key, clause_value)

    debug_process_node(:after, node, acc)

    {node, acc}
  end

  defp process_node({first_step, _, _} = node, acc) when is_atom(first_step) do
    debug_process_node(:before, node, acc)

    acc = accumulate_node(acc, node, %Step{key: first_step})

    debug_process_node(:after, node, acc)

    {node, acc}
  end

  defp process_node(step, acc) when is_atom(step) do
    debug_process_node(:before, step, acc)

    acc = accumulate_node(acc, step, %Step{key: step})

    debug_process_node(:after, step, acc)

    {step, acc}
  end

  defp process_node(index, acc) when is_integer(index) do
    debug_process_node(:before, index, acc)

    acc =
      acc
      |> accumulate_node(index)
      |> update_last_step_index(index)

    debug_process_node(:after, index, acc)

    {index, acc}
  end

  defp process_node(node, acc) do
    debug_process_node(:before, node, acc)

    acc = accumulate_node(acc, node)

    debug_process_node(:after, node, acc)

    {node, acc}
  end

  defp negate_last_step_index(%{steps: [last_step | rest_steps]} = acc) do
    updated_step = %{last_step | index: -last_step.index}

    %{acc | steps: [updated_step | rest_steps]}
  end

  defp update_last_step_where(%{steps: [_single_step]} = acc, clause_key, clause_value)
       when is_integer(clause_value) or is_binary(clause_value) do
    # this happens when the `where` clause is the first step, e.g. Addresses~>[first_line="foo"]

    # let's add a dummy step to make the following clause happy
    acc
    |> add_dummy_step()
    |> increment_expected_index_steps()
    |> update_last_step_where(clause_key, clause_value)
  end

  defp update_last_step_where(%{steps: [_last_step | rest_steps]} = acc, clause_key, clause_value)
       when is_integer(clause_value) or is_binary(clause_value) do
    # the last_step is about the "key" used by the where clause, so we drop it
    # and add the where clause to the last_step of the rest_steps
    [step_to_update | rest_steps] = rest_steps
    updated_where = Keyword.put(step_to_update.where || [], clause_key, clause_value)
    updated_step = %{step_to_update | where: updated_where, index: nil}

    %{acc | steps: [updated_step | rest_steps]}
  end

  defp update_last_step_where(
         %{steps: [last_step, before_last_step | rest_steps]} = acc,
         clause_key,
         clause_value
       )
       when is_atom(clause_value) do
    # atoms are being collected as separate steps
    %Step{key: ^clause_value} = last_step
    %Step{key: ^clause_key} = before_last_step

    # if `where` clause is the first one after operator
    # e.g. Addresses~>[first_line="foo"].bar.baz[23]
    # `rest_steps` here are []
    where_clause_is_first? = rest_steps == []

    [step_to_update | rest_steps] =
      if where_clause_is_first? do
        [before_last_step]
      else
        rest_steps
      end

    updated_where = Keyword.put(step_to_update.where || [], clause_key, clause_value)
    updated_step = %{step_to_update | where: updated_where}

    acc = %{acc | steps: [updated_step | rest_steps]}

    if where_clause_is_first? do
      increment_expected_index_steps(acc)
    else
      acc
    end
  end

  defp add_dummy_step(%{steps: steps} = acc) do
    %{acc | steps: [:dummy_step | steps]}
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

  defp validate_step(current, %Step{key: nil} = step) when is_map_key(current, :__schema__) do
    {:ok, step}
  end

  defp validate_step(current, %Step{key: step_key} = step) when is_map(current) do
    case step_key in Map.keys(current) do
      true -> {:ok, step}
      _ -> {:error, :invalid_step}
    end
  end

  defp validate_step(nil, _step) do
    {:error, :current_is_nil}
  end

  defp validate_step(_current, _step) do
    {:error, :current_not_struct}
  end

  if System.get_env("ECTO_EXPLORER_DEBUG") == "true" do
    defp debug_process_node(moment, node, acc) do
      if moment == :before do
        Logger.debug("[process_node] #{moment} #{String.duplicate("=", 50)}")
      else
        Logger.debug("[process_node] #{moment}")
      end

      Logger.debug("[process_node] Node: #{inspect(node)}\n\nAcc: #{inspect(acc)}")
    end
  else
    defp debug_process_node(_moment, _node, _acc), do: :noop
  end
end
