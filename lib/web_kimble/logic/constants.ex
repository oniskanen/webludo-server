defmodule WebKimble.Logic.Constants do

    alias WebKimble.Logic.Piece
    
    @colors [:red, :blue, :yellow, :green]
    # @areas [:home, :play, :goal]
    @starting_indices [0, 1, 2, 3]

    def initialPieces do
        (for c <- @colors, i <- @starting_indices, do: %Piece{color: c, position_index: i, area: :home})
    end

end