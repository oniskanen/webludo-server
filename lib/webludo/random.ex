defmodule WebLudo.Random do
  def even_grouping([], num_bins) when is_integer(num_bins) and num_bins > 0 do
    1..num_bins |> Enum.map(fn _ -> [] end)
  end

  def even_grouping(objects, num_bins)
      when is_integer(num_bins) and num_bins > 0 and is_list(objects) do
    shuffled = Enum.shuffle(objects)

    indices = Stream.cycle(0..(num_bins - 1))

    Enum.zip(shuffled, indices)
    |> Enum.group_by(fn {_, i} -> i end, fn {o, _} -> o end)
    |> Map.values()
    |> Enum.shuffle()
  end
end
