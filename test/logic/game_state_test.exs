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

        moves = Logic.get_moves(6, gamestate).yellow

        assert 4 = length moves

        assert Enum.all?(moves, fn(m) -> m.current.player_color == :yellow and m.target.player_color == :yellow end)
        assert Enum.all?(moves, fn(m) -> m.current.area == :home end)
        assert Enum.all?(moves, fn(m) -> m.target.area == :play end)
    end

    test "cannot move from home without roll of 6" do
        game_state = WebKimble.TestHelpers.game_state_fixture()
        
        assert nil == Logic.get_moves(1, game_state)[game_state.current_player]
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
        
        moves = Logic.get_moves(6, gamestate)[player]

        assert 1 = length moves

        [move | _tail] = moves

        assert expected_index == move.target.position_index
    end

    
end

