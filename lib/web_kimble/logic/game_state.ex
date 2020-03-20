defmodule WebKimble.Logic.GameState do
    alias WebKimble.Logic.Constants
    alias WebKimble.Logic.Move

    defstruct current_player: :red, pieces: Constants.initial_pieces

    def get_home_space_index(player) do
        case player do
            :red -> 0
            :blue -> 6
            :yellow -> 12
            :green -> 18
        end
    end

    def get_moves(roll, gamestate) do
        gamestate.pieces
        |> Enum.filter(fn(p) -> p.player == gamestate.current_player end)
        |> Enum.map(fn(p) -> %Move{player: p.player, current_area: p.area, current_index: p.position_index, target_area: :play, target_index: get_home_space_index(p.player)} end)
        |> Enum.filter(fn(_m) -> roll == 6 end)        
        # |> Enum.filter(fn(m) -> (m.current_area != :home || roll == 6) end)        
    end
end