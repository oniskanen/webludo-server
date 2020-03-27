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
        gamestate = WebKimble.TestHelpers.game_state_fixture(%{current_player: :yellow, roll: 6})

        moves = Logic.get_moves(gamestate)

        assert 4 = length moves
        
        assert Enum.all?(moves, fn(m) -> m.target_area == :play end)
    end

    test "cannot move from home without roll of 6" do
        game_state = WebKimble.TestHelpers.game_state_fixture(%{roll: 1})
        
        assert [] == Logic.get_moves(game_state)
    end

    test "moving from home to play sets correct index" do
        test_start_index(:red, 0)
        test_start_index(:blue, 6)
        test_start_index(:yellow, 12)
        test_start_index(:green, 18)
    end

    defp test_start_index(player, expected_index) do
        attrs = %{current_player: player, roll: 6, pieces: [%{area: :home, position_index: 0, player_color: player}]}
        gamestate = WebKimble.TestHelpers.game_state_fixture(attrs)
        
        moves = Logic.get_moves(gamestate)

        assert 1 = length moves

        [move | _tail] = moves

        assert expected_index == move.target_index
    end

    test "moving in play adds to position index" do
        attrs = %{current_player: :red, roll: 3, pieces: [%{area: :play, position_index: 0, player_color: :red}]}

        game_state = WebKimble.TestHelpers.game_state_fixture(attrs)

        moves = Logic.get_moves(game_state)

        assert [move | []] = moves

        assert %{target_index: 3, target_area: :play} = move
    end
    
end

