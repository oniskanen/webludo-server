defmodule WebLudo.Logic.HemboTest do
  use ExUnit.Case

  alias WebLudo.Logic
  alias WebLudo.TestHelpers

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "a player getting all pieces moved to home by getting eaten gets needs_hembo flag set to true" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :blue},
        %{area: :home, position_index: 0, player_color: :blue},
        %{area: :home, position_index: 1, player_color: :blue},
        %{area: :home, position_index: 2, player_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {%{players: players}, _changes} = Logic.execute_move(game, move)

    blue = Enum.find(players, &match?(%{color: :blue}, &1))
    assert blue.needs_hembo
  end

  test "a player getting all pieces moved to home by a raise gets needs_hembo flag set to true" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :red},
        %{area: :play, position_index: 2, player_color: :red},
        %{area: :play, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :home, position_index: 0, player_color: :blue},
        %{area: :home, position_index: 1, player_color: :blue},
        %{area: :home, position_index: 2, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :play, position_index: 0, player_color: :yellow},
        %{area: :home, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {%{players: players}, _changes} = Logic.execute_move(game, move)
    blue = Enum.find(players, &match?(%{color: :blue}, &1))
    yellow = Enum.find(players, &match?(%{color: :yellow}, &1))

    assert blue.needs_hembo
    assert not yellow.needs_hembo
  end

  test "a player is assigned a penalty when player needs hembo and missed hembo is called" do
    attrs = %{
      players: [%{name: "Player 1", color: :red, needs_hembo: true, penalties: 1}]
    }

    game = TestHelpers.game_fixture(attrs)

    assert {:ok, game} = Logic.call_missed_hembo(game, :red)
    assert %{players: [%{color: :red, penalties: 2, needs_hembo: false}]} = game
  end

  test "a player is assigned a penalty when player who does not need hembo calls jag bor i hembo" do
    attrs = %{
      players: [%{name: "Player 1", color: :red, needs_hembo: false, penalties: 1}]
    }

    game = TestHelpers.game_fixture(attrs)

    {game, penalties} = Logic.jag_bor_i_hembo(game, :red)
    assert %{players: [%{color: :red, penalties: 2, needs_hembo: false}]} = game
    assert [%{amount: 1, player_color: :red}] = penalties
  end

  test "a player who needs to call hembo can call hembo to set needs_hembo to false" do
    attrs = %{
      players: [%{name: "Player 1", color: :red, needs_hembo: true, penalties: 1}]
    }

    game = TestHelpers.game_fixture(attrs)

    {game, penalties} = Logic.jag_bor_i_hembo(game, :red)
    assert %{players: [%{color: :red, penalties: 1, needs_hembo: false}]} = game
    assert [] = penalties
  end
end
