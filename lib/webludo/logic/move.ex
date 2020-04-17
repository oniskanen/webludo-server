defmodule WebLudo.Logic.Move do
  @derive {Jason.Encoder, only: [:piece_id, :target_area, :target_index, :type]}
  defstruct [:piece_id, :target_area, :target_index, type: "move"]
end
