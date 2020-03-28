defmodule WebKimble.Logic.Constants do

    alias WebKimble.Logic.Piece
    
    @player_colors [:red, :blue, :yellow, :green]
    # @areas [:home, :play, :goal]
    @starting_indices [0, 1, 2, 3]

    @max_rolls 3
    

    def initial_pieces do
        (for p <- @player_colors, i <- @starting_indices, do: %{player_color: p, position_index: i, area: :home})
    end

    def play_track_length do
        24
    end

    def goal_track_length do
        4
    end

    def get_home_space_index(player_color) do
        case player_color do
            :red -> 0
            :blue -> 6
            :yellow -> 12
            :green -> 18
        end
    end

    def player_colors do
        @player_colors
    end
end