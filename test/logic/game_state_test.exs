defmodule WebKimble.Logic.GameStateTest do
    use ExUnit.Case

    alias WebKimble.Logic
    alias WebKimble.Repo

    setup do
        # Explicitly get a connection before each test
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebKimble.Repo)
    end

    test "gamestate has current player" do
        gamestate = WebKimble.TestHelpers.game_state_fixture(%{current_player: :yellow})

        assert :yellow = gamestate.current_player
    end

    test "gamestate has 16 pieces" do
        gamestate = WebKimble.TestHelpers.game_state_fixture()
        gamestate = Repo.preload(gamestate, :pieces)

        assert 16 = length gamestate.pieces
    end

    test "get_moves returns a list of possible moves" do
        gamestate = WebKimble.TestHelpers.game_state_fixture(%{current_player: :yellow})

        moves = Logic.get_moves(6, gamestate)

        assert 4 = length moves

        assert Enum.all?(moves, fn(m) -> m.player_color == :yellow end)
        assert Enum.all?(moves, fn(m) -> m.current_area == :home end)
        assert Enum.all?(moves, fn(m) -> m.target_area == :play end)
    end

    test "cannot move from home without roll of 6" do
        gamestate = WebKimble.TestHelpers.game_state_fixture()

        moves = Logic.get_moves(1, gamestate)

        assert 0 = length moves
    end

    test "moving from home to play sets correct index" do
        test_start_index(:red, 0)
        test_start_index(:blue, 6)
        test_start_index(:yellow, 12)
        test_start_index(:green, 18)
    end

    defp test_start_index(player, expected_index) do
        attrs = %{current_player: player, pieces: [%{area: :home, position_index: 0, player_color: player}]}
        gamestate = WebKimble.TestHelpers.game_state_fixture(attrs)

        #gamestate = %GameState{current_player: player, pieces: }
        
        moves = Logic.get_moves(6, gamestate)

        assert 1 = length moves

        [move | _tail] = moves

        assert expected_index == move.target_index
    end

    
end

