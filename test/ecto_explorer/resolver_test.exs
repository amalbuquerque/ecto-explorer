defmodule EctoExplorer.ResolverTest do
  use ExUnit.Case, async: true

  alias EctoExplorer.Repo
  alias EctoExplorer.Resolver, as: Subject
  alias EctoExplorer.Resolver.Step

  alias EctoExplorer.Schemas.{
    Flag,
    Country,
    Address,
    Currency
  }

  describe "resolve/2" do
    test "it resolves a basic step" do
      current = Repo.get_by(Country, code: "ECU")

      assert "ECU" == Subject.resolve(current, %Step{key: :code})
    end
  end

  describe "steps/1" do
    test "makes steps for a basic right-hand side" do
      rhs = quote do: foo

      assert [%Step{key: :foo}] == Subject.steps(rhs)
    end

    test "makes steps for a 2-hop right-hand side" do
      rhs = quote do: foo.bar

      assert [%Step{key: :foo}, %Step{key: :bar}] == Subject.steps(rhs)
    end

    test "makes steps for a 5-hop right-hand side" do
      rhs = quote do: foo.bar.baz.bin.yas

      assert [
               %Step{key: :foo},
               %Step{key: :bar},
               %Step{key: :baz},
               %Step{key: :bin},
               %Step{key: :yas}
             ] == Subject.steps(rhs)
    end

    test "makes steps for a basic right-hand side with index" do
      rhs = quote do: foo[99]

      assert [%Step{key: :foo, index: 99}] == Subject.steps(rhs)
    end

    test "makes steps for a 2-hop right-hand side, the first with index" do
      rhs = quote do: foo[77].bar

      assert [%Step{key: :foo, index: 77}, %Step{key: :bar}] == Subject.steps(rhs)
    end

    test "makes steps for a 2-hop right-hand side, the last with index" do
      rhs = quote do: foo.bar[42]

      assert [%Step{key: :foo}, %Step{key: :bar, index: 42}] == Subject.steps(rhs)
    end

    test "makes steps for a 5-hop right-hand side, the first with index" do
      rhs = quote do: foo[34].bar.baz.bin.yas

      assert [
               %Step{key: :foo, index: 34},
               %Step{key: :bar},
               %Step{key: :baz},
               %Step{key: :bin},
               %Step{key: :yas}
             ] == Subject.steps(rhs)
    end

    test "makes steps for a 5-hop right-hand side, the last with index" do
      rhs = quote do: foo.bar.baz.bin.yas[8]

      assert [
               %Step{key: :foo},
               %Step{key: :bar},
               %Step{key: :baz},
               %Step{key: :bin},
               %Step{key: :yas, index: 8}
             ] == Subject.steps(rhs)
    end

    test "makes steps for a 5-hop right-hand side, first and last with index" do
      rhs = quote do: foo[42].bar.baz.bin.yas[8]

      assert [
               %Step{key: :foo, index: 42},
               %Step{key: :bar},
               %Step{key: :baz},
               %Step{key: :bin},
               %Step{key: :yas, index: 8}
             ] == Subject.steps(rhs)
    end

    test "makes steps for a 5-hop right-hand side, a couple with index" do
      rhs = quote do: foo.bar[42].baz.bin[8].yas

      assert [
               %Step{key: :foo},
               %Step{key: :bar, index: 42},
               %Step{key: :baz},
               %Step{key: :bin, index: 8},
               %Step{key: :yas}
             ] == Subject.steps(rhs)
    end

    test "makes steps for a 5-hop right-hand side, all with index" do
      rhs = quote do: foo[1].bar[42].baz[3].bin[8].yas[5]

      assert [
               %Step{key: :foo, index: 1},
               %Step{key: :bar, index: 42},
               %Step{key: :baz, index: 3},
               %Step{key: :bin, index: 8},
               %Step{key: :yas, index: 5}
             ] == Subject.steps(rhs)
    end

    test "makes steps for a 2-hop right-hand side, the first with negative index" do
      rhs = quote do: foo[-2].bar

      assert [%Step{key: :foo, index: -2}, %Step{key: :bar}] == Subject.steps(rhs)
    end

    test "makes steps for a 2-hop right-hand side, the last with negative index" do
      rhs = quote do: foo.bar[-42]

      assert [%Step{key: :foo}, %Step{key: :bar, index: -42}] == Subject.steps(rhs)
    end

    test "raises error if the index is not integer (string)" do
      rhs = quote do: foo.bar["oops"]

      assert_raise ArgumentError, fn ->
        Subject.steps(rhs)
      end
    end

    test "raises error if the index is not integer (atom)" do
      rhs = quote do: foo.bar[:oops]

      assert_raise ArgumentError, fn ->
        Subject.steps(rhs)
      end
    end
  end
end
