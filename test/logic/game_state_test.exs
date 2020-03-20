defmodule WebKimble.Logic.GameStateTest do
    use ExUnit.Case, async: true

    alias WebKimble.Logic.GameState

    test "gamestate has current player" do
        gamestate = %GameState{current_player: :yellow}

        assert :yellow = gamestate.current_player
    end

    test "gamestate has 16 pieces" do
        gamestate = %GameState{current_player: :yellow}

        assert 16 = length gamestate.pieces
    end
    
end

