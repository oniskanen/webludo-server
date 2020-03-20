defmodule WebKimble.Logic.GameStateTest do
    use ExUnit.Case, async: true

    alias WebKimble.Logic.GameState
    alias WebKimble.Logic.Piece

    test "gamestate has current player" do
        gamestate = %GameState{current_player: :yellow}

        assert :yellow = gamestate.current_player
    end

    test "gamestate has 16 pieces" do
        gamestate = %GameState{current_player: :yellow}

        assert 16 = length gamestate.pieces
    end

    test "get_moves returns a list of possible moves" do
        gamestate = %GameState{current_player: :yellow}

        moves = GameState.get_moves(6, gamestate)

        assert 4 = length moves

        assert Enum.all?(moves, fn(m) -> m.player == :yellow end)
        assert Enum.all?(moves, fn(m) -> m.current_area == :home end)
        assert Enum.all?(moves, fn(m) -> m.target_area == :play end)
    end

    test "cannot move from home without roll of 6" do
        gamestate = %GameState{current_player: :yellow}

        moves = GameState.get_moves(1, gamestate)

        assert 0 = length moves
    end

    test "moving from home to play sets correct index" do
        test_start_index(:red, 0)
        test_start_index(:blue, 6)
        test_start_index(:yellow, 12)
        test_start_index(:green, 18)
    end

    defp test_start_index(player, expected_index) do
        gamestate = %GameState{current_player: player, pieces: [%Piece{area: :home, position_index: 0, player: player}]}
        
        moves = GameState.get_moves(6, gamestate)

        assert 1 = length moves

        [move | _tail] = moves

        assert expected_index == move.target_index
    end




    
end

