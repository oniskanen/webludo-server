defmodule WebLudo.Logic.GameTest do
  use ExUnit.Case

  alias WebLudo.Logic
  alias WebLudo.Repo
  alias WebLudo.TestHelpers

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "game has current team" do
    game = TestHelpers.game_fixture(%{current_team: :yellow})

    assert :yellow = game.current_team
  end

  test "game has 16 pieces" do
    game = TestHelpers.game_fixture()
    game = Repo.preload(game, :pieces)

    assert 16 = length(game.pieces)
  end

  test "get_moves returns a list of possible moves" do
    game = TestHelpers.game_fixture(%{current_team: :yellow, roll: 6})

    moves = Logic.get_moves(game)

    assert 4 = length(moves)

    assert Enum.all?(moves, fn m -> m.target_area == :play end)
  end

  test "cannot move from home without roll of 6" do
    game = TestHelpers.game_fixture(%{roll: 1})

    assert [] == Logic.get_moves(game)
  end

  test "moving from home to play sets correct index" do
    test_start_index(:red, 0)
    test_start_index(:blue, 7)
    test_start_index(:yellow, 14)
    test_start_index(:green, 21)
  end

  defp test_start_index(team, expected_index) do
    attrs = %{
      current_team: team,
      roll: 6,
      pieces: [%{area: :home, position_index: 0, team_color: team}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert 1 = length(moves)

    [move | _tail] = moves

    assert expected_index == move.target_index
  end

  test "moving in play adds to position index" do
    attrs = %{
      current_team: :red,
      roll: 3,
      pieces: [%{area: :play, position_index: 0, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [move | []] = moves

    assert %{target_index: 3, target_area: :play} = move
  end

  test "moving at end of play track moves to goal" do
    attrs = %{
      current_team: :red,
      roll: 5,
      pieces: [%{area: :play, position_index: 24, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [move | []] = moves

    assert %{target_index: 1, target_area: :goal} = move
  end

  test "no team can move back to starting point" do
    validate_piece_in_goal(:red, 27)
    validate_piece_in_goal(:blue, 6)
    validate_piece_in_goal(:yellow, 13)
    validate_piece_in_goal(:green, 20)
  end

  defp validate_piece_in_goal(team, index) do
    attrs = %{
      current_team: team,
      roll: 1,
      pieces: [%{area: :play, position_index: index, team_color: team}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [move | []] = moves

    assert %{target_index: 0, target_area: :goal} = move
  end

  test "teams move in play from starting point" do
    validate_piece_in_play(:red, 0)
    validate_piece_in_play(:blue, 7)
    validate_piece_in_play(:yellow, 14)
    validate_piece_in_play(:green, 21)
  end

  defp validate_piece_in_play(team, index) do
    attrs = %{
      current_team: team,
      roll: 1,
      pieces: [%{area: :play, position_index: index, team_color: team}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [move | []] = moves

    expected = index + 1
    assert %{target_index: ^expected, target_area: :play} = move
  end

  test "piece in goal can move" do
    attrs = %{
      current_team: :red,
      roll: 1,
      pieces: [%{area: :goal, position_index: 0, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [move | []] = moves

    assert %{target_index: 1, target_area: :goal} = move
  end

  test "piece in goal cannot move past end" do
    attrs = %{
      current_team: :red,
      roll: 4,
      pieces: [%{area: :goal, position_index: 0, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [] = moves
  end

  test "piece in play cannot move past goal end" do
    attrs = %{
      current_team: :red,
      roll: 5,
      pieces: [%{area: :goal, position_index: 23, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [] = moves
  end

  test "piece cannot move on top of another piece of the same team" do
    attrs = %{
      current_team: :red,
      roll: 1,
      pieces: [
        %{area: :play, position_index: 22, team_color: :red},
        %{area: :play, position_index: 23, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)
    moves = Logic.get_moves(game)

    assert [move | []] = moves

    assert %{target_index: 24, target_area: :play} = move
  end

  test "piece cannot move on top of pieces in goal with a roll of 6" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :play, position_index: 24, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)
    assert [] = Logic.get_moves(game)
  end

  test "moving causes the current team to change" do
    attrs = %{
      current_team: :red,
      roll: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :home, position_index: 0, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [move | []] = moves

    assert %{target_index: 1, target_area: :goal} = move

    {state, _move} = Logic.execute_move(game, move)

    assert %{current_team: :blue} = state
  end

  test "team cannot move without rolling first" do
    attrs = %{
      current_team: :red,
      pieces: [%{area: :goal, position_index: 0, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    assert [] = moves
  end

  test "team cannot roll twice in a row" do
    attrs = %{
      current_team: :red,
      roll_count: 0,
      pieces: [%{area: :goal, position_index: 0, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    assert {:ok, game} = Logic.set_roll(game, 1)
    assert {:error, message} = Logic.set_roll(game, 1)
  end

  test "roll results do not carry between teams" do
    attrs = %{
      current_team: :red,
      roll: 2,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :play, position_index: 7, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    {game, _move} = Logic.execute_move(game, hd(moves))

    assert %{roll: nil, current_team: :blue} = game
  end

  test "rolling a 6 gives another turn" do
    attrs = %{
      current_team: :red,
      roll: 6,
      pieces: [
        %{area: :play, position_index: 0, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    {game, _move} = Logic.execute_move(game, hd(moves))

    assert %{roll: nil, current_team: :red} = game
  end

  test "allow 3 rolls if no movable pieces" do
    attrs = %{
      current_team: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :home, position_index: 0, team_color: :red},
        %{area: :home, position_index: 1, team_color: :red},
        %{area: :home, position_index: 2, team_color: :red},
        %{area: :home, position_index: 3, team_color: :red},
        %{area: :home, position_index: 0, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    {:ok, game} = Logic.set_roll(game, 1)
    assert %{current_team: :red, roll: nil, roll_count: 1} = game

    {:ok, game} = Logic.set_roll(game, 2)
    assert %{current_team: :red, roll: nil, roll_count: 2} = game

    {:ok, game} = Logic.set_roll(game, 3)
    assert %{current_team: :blue, roll: nil, roll_count: 0} = game
  end

  test "moving resets roll count" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [%{area: :goal, position_index: 0, team_color: :red}]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {game, _move} = Logic.execute_move(game, move)

    assert %{roll_count: 0} = game
  end

  test "moving on top of another team's piece sends it home" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, team_color: :red},
        %{area: :play, position_index: 1, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {%{pieces: pieces} = _game, _move} = Logic.execute_move(game, move)

    assert Enum.any?(pieces, &match?(%{area: :home, team_color: :blue}, &1))
  end

  test "cannot roll several times if pieces in play have legal moves" do
    attrs = %{
      current_team: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :play, position_index: 27, team_color: :red},
        %{area: :home, position_index: 0, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    {:ok, game} = Logic.set_roll(game, 5)

    assert %{current_team: :blue} = game
  end

  test "can roll several times if pieces in goal are immobile" do
    attrs = %{
      current_team: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :goal, position_index: 3, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :home, position_index: 0, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    {:ok, game} = Logic.set_roll(game, 5)

    assert %{current_team: :red} = game
  end

  test "moving to a piece on it's start position gets the moving piece eaten" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, team_color: :red},
        %{area: :play, position_index: 7, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))
    move_piece_id = move.piece_id
    {_game, changes} = Logic.execute_move(game, move)

    assert %{animated_effects: [%{piece_id: piece_id, start_index: 7, target_index: 0}]} = changes
    assert move_piece_id == piece_id
  end

  test "cannot eat in same coordinates in goal" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :goal, position_index: 3, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))
    {_game, changes} = Logic.execute_move(game, move)

    refute match?(%{animated_effects: _effects}, changes)
  end

  test "piece walking into mine moves to first free home index" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, team_color: :red},
        %{area: :play, position_index: 7, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))
    {game, _changes} = Logic.execute_move(game, move)

    assert %{pieces: pieces} = game

    assert Enum.any?(pieces, &match?(%{position_index: 0, area: :home, team_color: :red}, &1))
  end

  test "moving a second piece to start position yields a double piece" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :home, position_index: 2, team_color: :red},
        %{area: :play, position_index: 0, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)
    assert 2 = length(moves)

    move = Enum.find(moves, &match?(%{target_area: :play, target_index: 0}, &1))
    {_game, changes} = Logic.execute_move(game, move)

    assert %{
             move: %{start_area: :home, start_index: 2, target_area: :center, target_index: 0},
             doubled: %{
               piece_id: _id,
               multiplier: 2
             }
           } = changes
  end

  test "tripling yields a different position index for the two center pieces" do
    attrs = %{
      current_team: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, team_color: :red, multiplier: 2},
        %{area: :home, position_index: 2, team_color: :red},
        %{area: :center, position_index: 0, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)
    assert 2 = length(moves)

    move = Enum.find(moves, &match?(%{target_area: :play, target_index: 0}, &1))
    {_game, changes} = Logic.execute_move(game, move)

    assert %{
             move: %{start_area: :home, start_index: 2, target_area: :center, target_index: 1},
             doubled: %{
               piece_id: _id,
               multiplier: 3
             }
           } = changes
  end

  test "a doubled piece arriving into goal zone places matching center pieces into goal" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 27, team_color: :red, multiplier: 2},
        %{area: :center, position_index: 0, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {_game, changes} = Logic.execute_move(game, move)

    assert %{
             move: %{start_area: :play, start_index: 27, target_area: :goal, target_index: 0},
             doubled: %{
               piece_id: _doubled_id,
               multiplier: 1
             },
             animated_effects: [
               %{
                 start_area: :center,
                 start_index: 0,
                 piece_id: _id,
                 target_area: :goal,
                 target_index: 0
               }
             ]
           } = changes
  end

  defp assert_member?(list, item) do
    assert Enum.member?(list, item)
  end

  test "eating a doubled piece causes the center piece to go to home" do
    attrs = %{
      current_team: :blue,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 27, team_color: :red, multiplier: 2},
        %{area: :center, position_index: 0, team_color: :red},
        %{area: :play, position_index: 26, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {game, changes} = Logic.execute_move(game, move)

    assert %{
             move: %{start_area: :play, start_index: 26, target_area: :play, target_index: 27},
             animated_effects: [
               %{
                 piece_id: _doubled_id,
                 start_area: :play,
                 target_area: :home,
                 start_index: 27,
                 target_index: 0
               },
               %{
                 piece_id: _doubled_id2,
                 start_area: :center,
                 target_area: :home,
                 start_index: 0,
                 target_index: 1
               }
             ]
           } = changes

    assert %{pieces: pieces} = game

    expected_pieces = [
      %{area: :play, position_index: 27, team_color: :blue, multiplier: 1},
      %{area: :home, position_index: 0, team_color: :red, multiplier: 1},
      %{area: :home, position_index: 1, team_color: :red, multiplier: 1}
    ]

    pieces =
      pieces
      |> Enum.map(fn p ->
        %{
          area: p.area,
          position_index: p.position_index,
          team_color: p.team_color,
          multiplier: p.multiplier
        }
      end)

    expected_pieces
    |> Enum.each(fn p -> assert_member?(pieces, p) end)
  end

  test "walking a doubled piece into mine causes the center piece to go to home" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, team_color: :red, multiplier: 2},
        %{area: :center, position_index: 0, team_color: :red},
        %{area: :play, position_index: 7, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {game, changes} = Logic.execute_move(game, move)

    assert %{
             move: %{start_area: :play, start_index: 6, target_area: :play, target_index: 7},
             animated_effects: [
               %{
                 piece_id: _doubled_id,
                 start_area: :play,
                 target_area: :home,
                 start_index: 7,
                 target_index: 0
               },
               %{
                 piece_id: _doubled_id2,
                 start_area: :center,
                 target_area: :home,
                 start_index: 0,
                 target_index: 1
               }
             ]
           } = changes

    assert %{pieces: pieces} = game

    expected_pieces = [
      %{area: :play, position_index: 7, team_color: :blue, multiplier: 1},
      %{area: :home, position_index: 0, team_color: :red, multiplier: 1},
      %{area: :home, position_index: 1, team_color: :red, multiplier: 1}
    ]

    pieces =
      pieces
      |> Enum.map(fn p ->
        %{
          area: p.area,
          position_index: p.position_index,
          team_color: p.team_color,
          multiplier: p.multiplier
        }
      end)

    expected_pieces
    |> Enum.each(fn p -> assert_member?(pieces, p) end)
  end

  test "walking into mine not a valid action if other moves available" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, team_color: :red},
        %{area: :play, position_index: 0, team_color: :red},
        %{area: :play, position_index: 7, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    assert [move | []] = Logic.get_moves(game)
    assert %{target_area: :play, target_index: 1} = move
  end

  test "rolling a 6 allows a re-roll even if no moves are available" do
    attrs = %{
      current_team: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :play, position_index: 27, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    {:ok, game} = Logic.set_roll(game, 6)
    assert %{current_team: :red, roll: nil, roll_count: 0} = game
  end

  test "a team with all pieces in goal area indices 0-3 gets skipped" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 27, team_color: :red},
        %{area: :goal, position_index: 3, team_color: :blue},
        %{area: :goal, position_index: 2, team_color: :blue},
        %{area: :goal, position_index: 1, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :home, position_index: 0, team_color: :yellow}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {game, _changes} = Logic.execute_move(game, move)

    assert %{current_team: :yellow, roll: nil, roll_count: 0} = game
  end

  test "a piece getting eaten lists a penalty for the eaten team" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, team_color: :red},
        %{area: :play, position_index: 1, team_color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {_game, changes} = Logic.execute_move(game, move)

    assert %{penalties: [%{team: :blue, amount: 1}]} = changes
  end

  test "listed penalty is equal to multiplier of eating piece times multiplier of target piece" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, team_color: :red, multiplier: 3},
        %{area: :play, position_index: 1, team_color: :blue, multiplier: 2},
        %{area: :center, position_index: 0, team_color: :blue},
        %{area: :center, position_index: 0, team_color: :red},
        %{area: :center, position_index: 1, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {_game, changes} = Logic.execute_move(game, move)

    assert %{penalties: [%{team: :blue, amount: 6}]} = changes
  end

  test "walking into a mine lists a penalty for the current team" do
    attrs = %{
      current_team: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, team_color: :red, multiplier: 3},
        %{area: :play, position_index: 7, team_color: :blue, multiplier: 2},
        %{area: :center, position_index: 0, team_color: :blue},
        %{area: :center, position_index: 0, team_color: :red},
        %{area: :center, position_index: 1, team_color: :red}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {_game, changes} = Logic.execute_move(game, move)

    assert %{penalties: [%{team: :red, amount: 6}]} = changes
  end

  test "a team moving last piece into goal with no penalties sets has_finished to true" do
    attrs = %{
      current_team: :red,
      roll: 4,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :play, position_index: 27, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {%{teams: teams}, _changes} = Logic.execute_move(game, move)

    assert Enum.any?(teams, &match?(%{has_finished: true, color: :red}, &1))
  end

  test "a team finishing last penalty with all pieces in goal has_finished to true" do
    attrs = %{
      current_team: :red,
      roll: 4,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 1, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :goal, position_index: 3, team_color: :red}
      ],
      teams: [
        %{color: :red, penalties: 1}
      ]
    }

    assert %{teams: [%{id: team_id, color: :red, has_finished: false}]} =
             game = TestHelpers.game_fixture(attrs)

    assert {:ok,
            {%{
               teams: [%{id: ^team_id, color: :red, has_finished: true}]
             }, _finishing_teams}} = Logic.set_team_penalty(game, team_id, 0)
  end

  test "team with pieces in goal indices 0, 0, 2, 3 does not get has_finished set to true" do
    attrs = %{
      current_team: :red,
      roll: 4,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :red},
        %{area: :goal, position_index: 2, team_color: :red},
        %{area: :play, position_index: 27, team_color: :red},
        %{area: :goal, position_index: 0, team_color: :blue},
        %{area: :goal, position_index: 0, team_color: :yellow},
        %{area: :goal, position_index: 0, team_color: :green},
        %{area: :play, position_index: 0, team_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {%{teams: teams}, _changes} = Logic.execute_move(game, move)

    assert Enum.any?(teams, &match?(%{has_finished: false, color: :red}, &1))
  end

  test "next team gets assigned correctly when playing with only red, blue and yellow teams" do
    attrs = %{
      current_team: :yellow,
      roll: 4,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 1, team_color: :yellow},
        %{area: :play, position_index: 2, team_color: :blue},
        %{area: :play, position_index: 3, team_color: :red}
      ],
      teams: [
        %{color: :yellow, name: "Yellow team"},
        %{color: :blue, name: "Blue team"},
        %{color: :red, name: "Red team"}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    next_team = Logic.get_next_team(game)

    assert next_team == :red
  end
end
