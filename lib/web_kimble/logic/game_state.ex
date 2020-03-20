defmodule WebKimble.Logic.GameState do
    alias WebKimble.Logic.Constants

    defstruct current_player: :red, pieces: Constants.initialPieces

end