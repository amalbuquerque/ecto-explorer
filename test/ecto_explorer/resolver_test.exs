defmodule EctoExplorer.ResolverTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import ExUnit.CaptureLog

  alias EctoExplorer.Repo
  alias EctoExplorer.Resolver, as: Subject
  alias EctoExplorer.Resolver.Step

  alias EctoExplorer.Schemas.Address
  alias EctoExplorer.Schemas.Country
  alias EctoExplorer.Schemas.Flag

  setup_all do
    # we do this to start the agent that
    # points to the repo used by the resolver
    use EctoExplorer, repo: EctoExplorer.Repo

    :ok
  end

  describe "resolve/2" do
    test "it resolves a step even for a map" do
      current = %{potatoes: :good}

      assert :good == Subject.resolve(current, %Step{key: :potatoes})
    end

    test "it resolves a basic step" do
      current = Repo.get_by(Country, code: "ECU")

      assert "ECU" == Subject.resolve(current, %Step{key: :code})
    end

    test "it resolves an association step" do
      current = Repo.get_by(Country, code: "ECU")

      assert %Flag{colors: "YBR"} = Subject.resolve(current, %Step{key: :flag})
    end

    # this test depends on the DB, I wasn't able to
    # easily make it fail with the current DB model
    test "it resolves an association step ordering the association results" do
      current = Repo.get_by(Country, code: "PRT")

      {max_id_address, _second_updated_address} = mix_address_ids(current.id)

      addresses = Subject.resolve(current, %Step{key: :addresses})

      assert is_list(addresses)
      assert length(addresses) > 0

      last_address = addresses |> Enum.reverse() |> hd()

      assert last_address.id == max_id_address.id

      sorted_addresses = Enum.sort_by(addresses, & &1.id) |> Enum.map(& &1.id)

      assert Enum.map(addresses, & &1.id) == sorted_addresses
    end

    test "it resolves a basic step with an index" do
      current = %{numbers: [1, 2, 3, 4]}

      assert 1 == Subject.resolve(current, %Step{key: :numbers, index: 0})
    end

    test "it resolves a basic step with a negative index" do
      current = %{numbers: [1, 2, 3, 4]}

      assert 4 == Subject.resolve(current, %Step{key: :numbers, index: -1})
    end

    test "it resolves a basic step with another negative index" do
      current = %{numbers: [1, 2, 3, 4]}

      assert 1 == Subject.resolve(current, %Step{key: :numbers, index: -4})
    end

    test "it resolves a basic step as `nil` with an out-of-bounds index" do
      current = %{numbers: [1, 2, 3, 4]}

      refute Subject.resolve(current, %Step{key: :numbers, index: 4})
    end

    test "it resolves a basic step as `nil` with an out-of-bounds negative index" do
      current = %{numbers: [1, 2, 3, 4]}

      refute Subject.resolve(current, %Step{key: :numbers, index: -5})
    end

    test "it resolves an association step with an index" do
      current = Repo.get_by(Country, code: "PRT")

      all_addresses = Repo.all(from a in Address, where: a.country_id == ^current.id)
      first_address = Enum.min_by(all_addresses, & &1.id)

      assert first_address == Subject.resolve(current, %Step{key: :addresses, index: 0})
    end

    test "it resolves an association step with a negative index" do
      current = Repo.get_by(Country, code: "PRT")

      all_addresses = Repo.all(from a in Address, where: a.country_id == ^current.id)
      last_address = Enum.max_by(all_addresses, & &1.id)

      assert last_address == Subject.resolve(current, %Step{key: :addresses, index: -1})
    end

    test "it returns `nil` if current is nil" do
      current = nil

      refute Subject.resolve(current, %Step{key: :irrelevant})
    end

    test "it logs a warning message if resolved step is `nil`" do
      current = %{good_ol_nil: nil}

      assert capture_log(fn ->
               refute Subject.resolve(current, %Step{key: :good_ol_nil})
             end) =~ "Step 'good_ol_nil' resolved to `nil`"
    end

    for current <- [[:list], [], "a string"] do
      test "it borks if the current is not a map (current is '#{inspect(current)}')" do
        assert_raise ArgumentError, fn ->
          Subject.resolve(unquote(current), %Step{key: :potatoes})
        end
      end
    end

    test "it borks if the current doesn't include the step key" do
      current = Repo.get_by(Country, code: "ECU")

      assert_raise ArgumentError, fn ->
        Subject.resolve(current, %Step{key: :potatoes})
      end
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

    for {type, value} <- [{String, "oops"}, {Atom, :oops}] do
      test "raises error if the index is not integer (#{type})" do
        rhs =
          quote bind_quoted: [value: unquote(value)] do
            foo.bar[value]
          end

        assert_raise ArgumentError, fn ->
          Subject.steps(rhs)
        end
      end
    end
  end

  defp mix_address_ids(country_id) do
    addresses = Repo.all(from(a in Address, where: a.country_id == ^country_id))

    [first_address, second_address | _] = addresses
    max_address_id = Repo.aggregate(Address, :max, :id)

    new_address_id = max_address_id + 42

    changeset = Ecto.Changeset.change(first_address, id: new_address_id)

    {:ok, updated_first_address} = Repo.update(changeset)

    changeset = Ecto.Changeset.change(second_address, id: new_address_id - 1)

    {:ok, updated_second_address} = Repo.update(changeset)

    {updated_first_address, updated_second_address}
  end
end
