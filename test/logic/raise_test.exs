defmodule WebLudo.Logic.RaiseTest do
  use ExUnit.Case

  alias WebLudo.Logic
  alias WebLudo.TestHelpers

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "a team rolling a six can raise when criteria are met" do
    # Raising is available when a team
    # 1) Rolls a six on their turn,
    # 2) Has all pieces out of goal,
    # 3) And all teams have at least one piece in goal

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
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert 4 = length(moves)

    assert Enum.any?(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))
  end

  test "a team can raise when playing with less than 4 teams" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      teams: [
        %{color: :red},
        %{color: :yellow},
        %{color: :green}
      ],
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :play, position_index: 1, team_color: :red},
        %{area: :play, position_index: 2, team_color: :red},
        %{area: :play, position_index: 3, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert 4 = length(moves)

    assert Enum.any?(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))
  end

  test "a team raising has their opponents' pieces move to first free home space and own piece to start space" do
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
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert 4 = length(moves)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {game, changes} = Logic.execute_move(game, move)

    assert %{current_team: :red, roll: nil, roll_count: 0} = game

    assert Enum.any?(
             game.pieces,
             &match?(%{position_index: 0, area: :play, team_color: :red}, &1)
           )

    assert %{animated_effects: effects} = changes
    assert length(effects) == 3

    assert Enum.all?(effects, &match?(%{target_area: :home, target_index: 0}, &1))
  end

  test "a team raising can eat a piece in their starting space" do
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
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert 4 = length(moves)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {game, changes} = Logic.execute_move(game, move)

    assert %{current_team: :red, roll: nil, roll_count: 0} = game

    assert Enum.any?(
             game.pieces,
             &match?(%{position_index: 0, area: :play, team_color: :red}, &1)
           )

    assert %{animated_effects: effects} = changes
    assert length(effects) == 4

    assert Enum.any?(
             effects,
             &match?(%{target_area: :home, target_index: 1}, &1)
           )
  end

  test "a team raising can double a piece in their starting space" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :play, position_index: 2, team_color: :red},
        %{area: :play, position_index: 3, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {_game, changes} = Logic.execute_move(game, move)

    assert %{doubled: %{multiplier: 2}} = changes
  end

  test "a team can roll again if the only move available is a raise" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :play, position_index: 27, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    {:ok, game} = Logic.set_roll(game, 1)
    assert %{current_team: :red, roll_count: 1} = game
  end

  test "a team can raise if the only move available is a raise" do
    attrs = %{
      current_team: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :play, position_index: 27, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    {:ok, game} = Logic.set_roll(game, 6)
    [%{type: "raise"} | []] = Logic.get_moves(game)
  end

  test "a team cannot raise if they have can_raise set to false" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :goal, position_index: 3, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :play, position_index: 8, team_color: :blue},
        %{area: :play, position_index: 9, team_color: :blue},
        %{area: :play, position_index: 10, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :green}
      ],
      teams: [
        %{color: :red, can_raise: false},
        %{color: :blue},
        %{color: :yellow},
        %{color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert !Enum.any?(moves, &match?(%{type: "raise"}, &1))
  end

  test "can_raise is set to false after a team raises" do
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
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {game, _changes} = Logic.execute_move(game, move)

    %{teams: teams} = game

    team = Enum.find(teams, &match?(%{color: :red}, &1))
    assert team.can_raise == false
  end

  test "team can agree to a new raising round" do
    attrs = %{
      teams: [
        %{color: :red, can_raise: false},
        %{color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)
    team = Enum.find(game.teams, &match?(%{color: :red}, &1))

    assert %{teams: teams} = Logic.agree_to_new_raise(game, team, true)

    assert teams |> Enum.any?(&match?(%{new_raising_round: true, color: :red}, &1))
  end

  test "team can draw back agreement to a new raising round" do
    game = TestHelpers.game_fixture()
    team = Enum.find(game.teams, &match?(%{color: :red}, &1))
    game = Logic.agree_to_new_raise(game, team, true)
    team = Enum.find(game.teams, &match?(%{color: :red}, &1))

    game = Logic.agree_to_new_raise(game, team, false)

    assert game.teams |> Enum.all?(&match?(%{new_raising_round: false}, &1))
  end

  test "team can raise again after each team agrees to a new raising round" do
    attrs = %{
      teams: [
        %{color: :red, can_raise: false, new_raising_round: false},
        %{color: :blue, can_raise: false, new_raising_round: true},
        %{color: :yellow, can_raise: false, new_raising_round: true},
        %{color: :green, can_raise: false, new_raising_round: true}
      ]
    }

    game = TestHelpers.game_fixture(attrs)
    team = Enum.find(game.teams, &match?(%{color: :red}, &1))

    assert %{teams: teams} = Logic.agree_to_new_raise(game, team, true)

    assert teams |> Enum.all?(&match?(%{new_raising_round: false, can_raise: true}, &1))
  end

  test "a team that has finished is not affected by a raise" do
    attrs = %{
      current_team: :blue,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :goal, position_index: 3, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :play, position_index: 8, team_color: :blue},
        %{area: :play, position_index: 9, team_color: :blue},
        %{area: :play, position_index: 10, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :green}
      ],
      teams: [
        %{color: :red, has_finished: true},
        %{color: :blue},
        %{color: :yellow},
        %{color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {%{pieces: pieces}, _changes} = Logic.execute_move(game, move)

    red_pieces = pieces |> Enum.filter(fn p -> p.team_color == :red end)

    assert Enum.all?(
             red_pieces,
             &match?(%{area: :goal, team_color: :red}, &1)
           )
  end

  test "a team in goal with penalties remaining is affected by a raise" do
    attrs = %{
      current_team: :blue,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :goal, position_index: 3, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :play, position_index: 8, team_color: :blue},
        %{area: :play, position_index: 9, team_color: :blue},
        %{area: :play, position_index: 10, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :green}
      ],
      teams: [
        %{color: :red, penalties: 3},
        %{color: :blue},
        %{color: :yellow},
        %{color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {%{pieces: pieces}, _changes} = Logic.execute_move(game, move)

    red_pieces = pieces |> Enum.filter(fn p -> p.team_color == :red end)

    assert Enum.any?(
             red_pieces,
             &match?(%{area: :home, team_color: :red}, &1)
           )
  end

  test "a piece eaten when raising causes a penalty" do
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
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {_game, changes} = Logic.execute_move(game, move)

    assert %{penalties: [%{team: :green, amount: 1}]} = changes
  end
end
