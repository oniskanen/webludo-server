defmodule WebKimble.Logic.Constants do

    alias WebKimble.Logic.Piece
    
    @players [:red, :blue, :yellow, :green]
    # @areas [:home, :play, :goal]
    @starting_indices [0, 1, 2, 3]

    def initial_pieces do
        (for p <- @players, i <- @starting_indices, do: %Piece{player: p, position_index: i, area: :home})
    end

end