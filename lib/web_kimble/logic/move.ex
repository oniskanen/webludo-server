defmodule WebKimble.Logic.Move do
  @derive {Jason.Encoder, only: [:piece_id, :target_area, :target_index]}
  defstruct [:piece_id, :target_area, :target_index, type: "move"]
end
