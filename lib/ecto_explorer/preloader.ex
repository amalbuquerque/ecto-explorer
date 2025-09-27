defmodule EctoExplorer.Preloader do
  import Ecto.Query

  def preload(current, step_key) do
    preload_schema = step_module(current, step_key)
    preload_primary_key = preload_primary_key(current, step_key)
    preload_query = from record in preload_schema, order_by: [asc: ^preload_primary_key]

    EctoExplorer.cached_repo().preload(current, [{step_key, preload_query}])
  end

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
