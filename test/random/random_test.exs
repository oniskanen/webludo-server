defmodule WebLudo.RandomTest do
  use ExUnit.Case

  alias WebLudo.Random

  test "even grouping returns empty lists when given an empty array and 1 group" do
    groups = Random.even_grouping([], 1)

    assert groups == [[]]
  end
end
