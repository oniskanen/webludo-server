defmodule WebKimble.Logic.Move do
    @derive {Jason.Encoder, only: [:current, :target, :type]}
    defstruct [:current, :target, type: "move"]    
end