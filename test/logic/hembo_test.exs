defmodule WebLudo.Logic.HemboTest do
  use ExUnit.Case

  alias WebLudo.Logic
  alias WebLudo.TestHelpers

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "a team getting all pieces moved to home by getting eaten gets needs_hembo flag set to true" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, team_color: :red},
        %{area: :play, position_index: 1, team_color: :blue},
        %{area: :home, position_index: 0, team_color: :blue},
        %{area: :home, position_index: 1, team_color: :blue},
        %{area: :home, position_index: 2, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {%{teams: teams}, _changes} = Logic.execute_move(game, move)

    blue = Enum.find(teams, &match?(%{color: :blue}, &1))
    assert blue.needs_hembo
  end

  test "a team getting all pieces moved to home by a raise gets needs_hembo flag set to true" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :play, position_index: 1, team_color: :red},
        %{area: :play, position_index: 2, team_color: :red},
        %{area: :play, position_index: 3, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :home, position_index: 0, team_color: :blue},
        %{area: :home, position_index: 1, team_color: :blue},
        %{area: :home, position_index: 2, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :play, position_index: 0, team_color: :yellow},
        %{area: :home, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {%{teams: teams}, _changes} = Logic.execute_move(game, move)
    blue = Enum.find(teams, &match?(%{color: :blue}, &1))
    yellow = Enum.find(teams, &match?(%{color: :yellow}, &1))

    assert blue.needs_hembo
    assert not yellow.needs_hembo
  end

  test "a team is assigned a penalty when team needs hembo and missed hembo is called" do
    attrs = %{
      teams: [%{name: "Player 1", color: :red, needs_hembo: true, penalties: 1}]
    }

    game = TestHelpers.game_fixture(attrs)

    assert {:ok, game} = Logic.call_missed_hembo(game, :red)
    assert %{teams: [%{color: :red, penalties: 2, needs_hembo: false}]} = game
  end

  test "a team is assigned a penalty when player in team that does not need hembo calls jag bor i hembo" do
    attrs = %{
      teams: [%{name: "Team 1", color: :red, needs_hembo: false, penalties: 1}]
    }

    game = TestHelpers.game_fixture(attrs)

    {game, penalties} = Logic.jag_bor_i_hembo(game, :red)
    assert %{teams: [%{color: :red, penalties: 2, needs_hembo: false}]} = game
    assert [%{amount: 1, team_color: :red}] = penalties
  end

  test "a player in a team that needs to call hembo can call hembo to set needs_hembo to false" do
    attrs = %{
      teams: [%{name: "Player 1", color: :red, needs_hembo: true, penalties: 1}]
    }

    game = TestHelpers.game_fixture(attrs)

    {game, penalties} = Logic.jag_bor_i_hembo(game, :red)
    assert %{teams: [%{color: :red, penalties: 1, needs_hembo: false}]} = game
    assert [] = penalties
  end
end
