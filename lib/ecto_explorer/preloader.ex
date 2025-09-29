defmodule EctoExplorer.Preloader do
  import Ecto.Query

  alias EctoExplorer.Resolver.Step

  def preload(current, %Step{key: step_key} = step) do
    preload_schema = step_module(current, step_key)
    preload_primary_key = preload_primary_key(current, step_key)
    preload_query = from record in preload_schema, order_by: [asc: ^preload_primary_key]
    preload_query = maybe_apply_where_clauses(preload_query, step)

    EctoExplorer.cached_repo().preload(current, [{step_key, preload_query}])
  end

  defp maybe_apply_where_clauses(query, %Step{where: where_clauses})
       when is_list(where_clauses) do
    Enum.reduce(where_clauses, query, fn {where_key, where_value}, query ->
      where(query, [x], field(x, ^where_key) == ^where_value)
    end)
  end

  defp maybe_apply_where_clauses(query, _step), do: query

  defp preload_primary_key(current, step_key) do
    step_module = step_module(current, step_key)

    :primary_key
    |> step_module.__schema__()
    |> hd()
  end

  defp step_module(%{__struct__: current_struct} = current, step_key) do
    # e.g. %Ecto.Association.Has{} or BelongsTo{}
    with step_association when is_struct(step_association) <-
           current_struct.__schema__(:association, step_key),
         module when is_atom(module) <- Map.get(step_association, :queryable) do
      module
    else
      _ ->
        raise(
          "Struct #{inspect(current)} doesn't contain a `#{step_key}` association or its association doesn't have a valid `queryable` value."
        )
    end
  end
end
