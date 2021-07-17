defmodule EctoExplorerTest do
  use ExUnit.Case

  # so we can use the `~>/2` here
  import EctoExplorer, only: [~>: 2]

  alias EctoExplorer.Repo

  alias EctoExplorer.Schemas.{
    Flag,
    Country,
    Address,
    Currency
  }

  setup_all do
    # we do this to start the agent that
    # points to the repo used by the resolver
    use EctoExplorer, repo: EctoExplorer.Repo

    :ok
  end

  describe "~>/2" do
    test "it fetches a basic step" do
      flag = Repo.get_by(Flag, colors: "YBR")

      assert "YBR" == flag ~> colors
    end

    test "it returns `nil` if the current is `nil`" do
      flag = nil

      refute flag ~> colors
    end

    test "it raises an error if the property step isn't valid" do
      flag = Repo.get_by(Flag, colors: "YBR")

      assert_raise ArgumentError, fn ->
        flag ~> missing_property
      end
    end

    test "it fetches an association step" do
      flag = Repo.get_by(Flag, colors: "YBR")

      assert %Country{code: "ECU"} = flag ~> country
    end

    test "it fetches a property of an association" do
      flag = Repo.get_by(Flag, colors: "YBR")

      assert "Ecuador" == flag ~> country.name
    end

    test "it raises an error if a property of an association isn't valid" do
      flag = Repo.get_by(Flag, colors: "YBR")

      assert_raise ArgumentError, fn ->
        flag ~> country.missing_property
      end
    end

    test "it raises an error if a property of an association isn't valid (longer expression)" do
      flag = Repo.get_by(Flag, colors: "YBR")

      assert_raise ArgumentError, fn ->
        flag ~> country.currencies[0].missing_property
      end
    end
  end
end
