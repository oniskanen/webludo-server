defmodule WebLudo.RandomTest do
  use ExUnit.Case

  alias WebLudo.Random

  # TODO: Investigate property based testing for broader coverage of different situations

  test "even grouping returns empty lists when given an empty array and 1 group" do
    groups = Random.even_grouping([], 1)

    assert groups == [[]]
  end

  test "even grouping returns empty lists when given an empty array and 4 groups" do
    groups = Random.even_grouping([], 4)

    assert groups == [[], [], [], []]
  end

  test "even grouping returns 3 lists when given a random array and 3 groups" do
    groups = Random.even_grouping(Enum.to_list(1..21), 3)

    assert length(groups) == 3
  end

  test "lists returned by even grouping contain all the input elements" do
    input_elements = Enum.to_list(6..99)
    groups = Random.even_grouping(input_elements, 7)

    elements = Enum.flat_map(groups, fn g -> g end) |> Enum.sort()

    assert input_elements == elements
  end

  test "groups returned by even grouping vary in size by maximum of 1" do
    input_elements = Enum.to_list(1..10)
    groups = Random.even_grouping(input_elements, 4)

    assert Enum.all?(groups, fn g -> length(g) == 2 or length(g) == 3 end)
  end
end
