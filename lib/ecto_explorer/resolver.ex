defmodule EctoExplorer.Resolver do
  defmodule Step do
    defstruct [:key, :index]
  end

  @doc false
  def resolve(current, %Step{} = step) do
    with {:ok, step} <- validate_step(current, step) do
      _resolve(current, step)
    else
      _error ->
        raise ArgumentError, "Invalid step #{inspect(step)} when evaluating #{inspect(current)}"
    end
  end

  @doc false
  def _resolve(current, %Step{key: step_key, index: nil} = step) do
    case Map.get(current, step_key) do
      %Ecto.Association.NotLoaded{} ->
        current = EctoExplorer.cached_repo().preload(current, step_key)

        _resolve(current, step)

      value ->
        value
    end
  end

  @doc false
  def _resolve(current, %Step{key: step_key, index: index} = step) when is_integer(index) do
    case Map.get(current, step_key) do
      %Ecto.Association.NotLoaded{} ->
        # TODO: The preload needs to happen with a sort by ID,
        # otherwise the index is moot
        current = EctoExplorer.cached_repo().preload(current, step_key)

        _resolve(current, step)

      value when is_list(value) ->
        # TODO: Check the previous comment
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
    |> Macro.postwalk(%{visited: [], steps: [], expected_index_steps: 0}, fn
      # :get is the current node, and Access was the previous
      # so we know there will be one step with index
      :get, %{visited: [Access | _]} = acc ->
        acc =
          accumulate_node(acc, :get)
          |> increment_expected_index_steps()

        {:get, acc}

      Access, acc ->
        acc = accumulate_node(acc, Access)

        {Access, acc}

      {:-, _, _} = node, acc ->
        acc =
          accumulate_node(acc, node)
          |> negate_last_step_index()

        {node, acc}

      {:., _, _} = node, acc ->
        acc = accumulate_node(acc, node)

        {node, acc}

      {first_step, _, _} = node, acc when is_atom(first_step) ->
        acc = accumulate_node(acc, node, %Step{key: first_step})

        {node, acc}

      step, acc when is_atom(step) ->
        acc = accumulate_node(acc, step, %Step{key: step})

        {step, acc}

      index, acc when is_integer(index) ->
        acc =
          accumulate_node(acc, index)
          |> update_last_step_index(index)

        {index, acc}

      node, acc ->
        acc = accumulate_node(acc, node)

        {node, acc}
    end)
  end

  defp negate_last_step_index(%{steps: [last_step | rest_steps]} = acc) do
    updated_step = %{last_step | index: -last_step.index}

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

  def validate_step(_current, _step) do
    {:error, :current_not_struct}
  end
end
