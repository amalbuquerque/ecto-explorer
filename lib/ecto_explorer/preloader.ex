defmodule EctoExplorer.Preloader do
  def preload(current, step_key) do
    current = EctoExplorer.cached_repo().preload(current, step_key)

    current
    |> Map.get(step_key)
    |> maybe_sort_preloaded(current, step_key)
  end

  defp maybe_sort_preloaded(preloaded, current, step_key) when is_list(preloaded) do
    primary_key = preload_primary_key(current, step_key)

    # The preload needs to be sorted by primary key,
    # otherwise the index access provided by the EctoExplorer doesn't make much sense
    sorted_preloaded =
      current
      |> Map.get(step_key)
      |> Enum.sort_by(&Map.get(&1, primary_key))

    %{current | step_key => sorted_preloaded}
  end

  defp maybe_sort_preloaded(_preloaded, current, _step_key), do: current

  defp preload_primary_key(current, step_key) do
    step_module = step_module(current, step_key)

    step_module.__schema__(:primary_key)
    |> hd()
  end

  defp step_module(%{__struct__: current_struct} = current, step_key) do
    # e.g. %Ecto.Association.Has{}
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
