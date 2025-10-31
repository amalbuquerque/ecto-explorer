defmodule EctoExplorer.Utils do
  def is_schema_module?(module) when is_atom(module) do
    function_exported?(module, :__schema__, 1)
  end

  def is_schema_module?(_module), do: false
end
