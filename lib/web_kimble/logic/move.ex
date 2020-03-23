defmodule WebKimble.Logic.Move do
    @derive {Jason.Encoder, only: [:current, :target]}
    defstruct [:current, :target]
end