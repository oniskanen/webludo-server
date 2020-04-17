defmodule WebLudo.Logic.GameTest do
  use ExUnit.Case

  alias WebLudo.Logic
  alias WebLudo.Repo
  alias WebLudo.TestHelpers

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "gamestate has current player" do
    gamestate = TestHelpers.game_fixture(%{current_player: :yellow})

    assert :yellow = gamestate.current_player
  end

  test "gamestate has 16 pieces" do
    gamestate = TestHelpers.game_fixture()
    gamestate = Repo.preload(gamestate, :pieces)

    assert 16 = length(gamestate.pieces)
  end

  test "get_moves returns a list of possible moves" do
    gamestate = TestHelpers.game_fixture(%{current_player: :yellow, roll: 6})

    moves = Logic.get_moves(gamestate)

    assert 4 = length(moves)

    assert Enum.all?(moves, fn m -> m.target_area == :play end)
  end

  test "cannot move from home without roll of 6" do
    game_state = TestHelpers.game_fixture(%{roll: 1})

    assert [] == Logic.get_moves(game_state)
  end

  test "moving from home to play sets correct index" do
    test_start_index(:red, 0)
    test_start_index(:blue, 7)
    test_start_index(:yellow, 14)
    test_start_index(:green, 21)
  end

  defp test_start_index(player, expected_index) do
    attrs = %{
      current_player: player,
      roll: 6,
      pieces: [%{area: :home, position_index: 0, player_color: player}]
    }

    gamestate = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(gamestate)

    assert 1 = length(moves)

    [move | _tail] = moves

    assert expected_index == move.target_index
  end

  test "moving in play adds to position index" do
    attrs = %{
      current_player: :red,
      roll: 3,
      pieces: [%{area: :play, position_index: 0, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [move | []] = moves

    assert %{target_index: 3, target_area: :play} = move
  end

  test "moving at end of play track moves to goal" do
    attrs = %{
      current_player: :red,
      roll: 5,
      pieces: [%{area: :play, position_index: 24, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [move | []] = moves

    assert %{target_index: 1, target_area: :goal} = move
  end

  test "no player can move back to starting point" do
    validate_piece_in_goal(:red, 27)
    validate_piece_in_goal(:blue, 6)
    validate_piece_in_goal(:yellow, 13)
    validate_piece_in_goal(:green, 20)
  end

  defp validate_piece_in_goal(player, index) do
    attrs = %{
      current_player: player,
      roll: 1,
      pieces: [%{area: :play, position_index: index, player_color: player}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [move | []] = moves

    assert %{target_index: 0, target_area: :goal} = move
  end

  test "players move in play from starting point" do
    validate_piece_in_play(:red, 0)
    validate_piece_in_play(:blue, 7)
    validate_piece_in_play(:yellow, 14)
    validate_piece_in_play(:green, 21)
  end

  defp validate_piece_in_play(player, index) do
    attrs = %{
      current_player: player,
      roll: 1,
      pieces: [%{area: :play, position_index: index, player_color: player}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [move | []] = moves

    expected = index + 1
    assert %{target_index: ^expected, target_area: :play} = move
  end

  test "piece in goal can move" do
    attrs = %{
      current_player: :red,
      roll: 1,
      pieces: [%{area: :goal, position_index: 0, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [move | []] = moves

    assert %{target_index: 1, target_area: :goal} = move
  end

  test "piece in goal cannot move past end" do
    attrs = %{
      current_player: :red,
      roll: 4,
      pieces: [%{area: :goal, position_index: 0, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [] = moves
  end

  test "piece in play cannot move past goal end" do
    attrs = %{
      current_player: :red,
      roll: 5,
      pieces: [%{area: :goal, position_index: 23, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [] = moves
  end

  test "piece cannot move on top of another piece of the same player" do
    attrs = %{
      current_player: :red,
      roll: 1,
      pieces: [
        %{area: :play, position_index: 22, player_color: :red},
        %{area: :play, position_index: 23, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)
    moves = Logic.get_moves(game_state)

    assert [move | []] = moves

    assert %{target_index: 24, target_area: :play} = move
  end

  test "piece cannot move on top of pieces in goal with a roll of 6" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :play, position_index: 24, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)
    assert [] = Logic.get_moves(game_state)
  end

  test "moving causes the current player to change" do
    attrs = %{
      current_player: :red,
      roll: 1,
      pieces: [%{area: :goal, position_index: 0, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [move | []] = moves

    assert %{target_index: 1, target_area: :goal} = move

    {state, _move} = Logic.execute_move(game_state, move)

    assert %{current_player: :blue} = state
  end

  test "player cannot move without rolling first" do
    attrs = %{
      current_player: :red,
      pieces: [%{area: :goal, position_index: 0, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert [] = moves
  end

  test "player cannot roll twice in a row" do
    attrs = %{
      current_player: :red,
      roll_count: 0,
      pieces: [%{area: :goal, position_index: 0, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    assert {:ok, game_state} = Logic.set_roll(game_state, 1)
    assert {:error, message} = Logic.set_roll(game_state, 1)
  end

  test "roll results do not carry between players" do
    attrs = %{
      current_player: :red,
      roll: 2,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 7, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    {game_state, _move} = Logic.execute_move(game_state, hd(moves))

    assert %{roll: nil, current_player: :blue} = game_state
  end

  test "rolling a 6 gives another turn" do
    attrs = %{
      current_player: :red,
      roll: 6,
      pieces: [
        %{area: :play, position_index: 0, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    {game_state, _move} = Logic.execute_move(game_state, hd(moves))

    assert %{roll: nil, current_player: :red} = game_state
  end

  test "allow 3 rolls if no movable pieces" do
    attrs = %{
      current_player: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :home, position_index: 0, player_color: :red},
        %{area: :home, position_index: 1, player_color: :red},
        %{area: :home, position_index: 2, player_color: :red},
        %{area: :home, position_index: 3, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    {:ok, game_state} = Logic.set_roll(game_state, 1)
    assert %{current_player: :red, roll: nil, roll_count: 1} = game_state

    {:ok, game_state} = Logic.set_roll(game_state, 2)
    assert %{current_player: :red, roll: nil, roll_count: 2} = game_state

    {:ok, game_state} = Logic.set_roll(game_state, 3)
    assert %{current_player: :blue, roll: nil, roll_count: 0} = game_state
  end

  test "moving resets roll count" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [%{area: :goal, position_index: 0, player_color: :red}]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {game_state, _move} = Logic.execute_move(game_state, move)

    assert %{roll_count: 0} = game_state
  end

  test "moving on top of another player sends them home" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {%{pieces: pieces} = _game_state, _move} = Logic.execute_move(game_state, move)

    assert Enum.any?(pieces, &match?(%{area: :home, player_color: :blue}, &1))
  end

  test "cannot roll several times if pieces in play have legal moves" do
    attrs = %{
      current_player: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :play, position_index: 27, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    {:ok, game_state} = Logic.set_roll(game_state, 5)

    assert %{current_player: :blue} = game_state
  end

  test "can roll several times if pieces in goal are immobile" do
    attrs = %{
      current_player: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :goal, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :home, position_index: 0, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    {:ok, game_state} = Logic.set_roll(game_state, 5)

    assert %{current_player: :red} = game_state
  end

  test "moving to a piece on it's start position gets the moving piece eaten" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, player_color: :red},
        %{area: :play, position_index: 7, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))
    move_piece_id = move.piece_id
    {_game_state, changes} = Logic.execute_move(game_state, move)

    assert %{animated_effects: [%{piece_id: piece_id, start_index: 7, target_index: 0}]} = changes
    assert move_piece_id == piece_id
  end

  test "cannot eat in same coordinates in goal" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :goal, position_index: 3, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))
    {_game_state, changes} = Logic.execute_move(game_state, move)

    refute match?(%{animated_effects: _effects}, changes)
  end

  test "piece walking into mine moves to first free home index" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, player_color: :red},
        %{area: :play, position_index: 7, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))
    {game_state, _changes} = Logic.execute_move(game_state, move)

    assert %{pieces: pieces} = game_state

    assert Enum.any?(pieces, &match?(%{position_index: 0, area: :home, player_color: :red}, &1))
  end

  test "moving a second piece to start position yields a double piece" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :home, position_index: 2, player_color: :red},
        %{area: :play, position_index: 0, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)
    assert 2 = length(moves)

    move = Enum.find(moves, &match?(%{target_area: :play, target_index: 0}, &1))
    {_game_state, changes} = Logic.execute_move(game_state, move)

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
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, player_color: :red, multiplier: 2},
        %{area: :home, position_index: 2, player_color: :red},
        %{area: :center, position_index: 0, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)
    assert 2 = length(moves)

    move = Enum.find(moves, &match?(%{target_area: :play, target_index: 0}, &1))
    {_game_state, changes} = Logic.execute_move(game_state, move)

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
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 27, player_color: :red, multiplier: 2},
        %{area: :center, position_index: 0, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {_game_state, changes} = Logic.execute_move(game_state, move)

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
      current_player: :blue,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 27, player_color: :red, multiplier: 2},
        %{area: :center, position_index: 0, player_color: :red},
        %{area: :play, position_index: 26, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {game_state, changes} = Logic.execute_move(game_state, move)

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

    assert %{pieces: pieces} = game_state

    expected_pieces = [
      %{area: :play, position_index: 27, player_color: :blue, multiplier: 1},
      %{area: :home, position_index: 0, player_color: :red, multiplier: 1},
      %{area: :home, position_index: 1, player_color: :red, multiplier: 1}
    ]

    pieces =
      pieces
      |> Enum.map(fn p ->
        %{
          area: p.area,
          position_index: p.position_index,
          player_color: p.player_color,
          multiplier: p.multiplier
        }
      end)

    expected_pieces
    |> Enum.each(fn p -> assert_member?(pieces, p) end)
  end

  test "walking a doubled piece into mine causes the center piece to go to home" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, player_color: :red, multiplier: 2},
        %{area: :center, position_index: 0, player_color: :red},
        %{area: :play, position_index: 7, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {game_state, changes} = Logic.execute_move(game_state, move)

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

    assert %{pieces: pieces} = game_state

    expected_pieces = [
      %{area: :play, position_index: 7, player_color: :blue, multiplier: 1},
      %{area: :home, position_index: 0, player_color: :red, multiplier: 1},
      %{area: :home, position_index: 1, player_color: :red, multiplier: 1}
    ]

    pieces =
      pieces
      |> Enum.map(fn p ->
        %{
          area: p.area,
          position_index: p.position_index,
          player_color: p.player_color,
          multiplier: p.multiplier
        }
      end)

    expected_pieces
    |> Enum.each(fn p -> assert_member?(pieces, p) end)
  end

  test "walking into mine not a valid action if other moves available" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, player_color: :red},
        %{area: :play, position_index: 0, player_color: :red},
        %{area: :play, position_index: 7, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    assert [move | []] = Logic.get_moves(game_state)
    assert %{target_area: :play, target_index: 1} = move
  end

  test "rolling a 6 allows a re-roll even if no moves are available" do
    attrs = %{
      current_player: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :play, position_index: 27, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    {:ok, game_state} = Logic.set_roll(game_state, 6)
    assert %{current_player: :red, roll: nil, roll_count: 0} = game_state
  end

  test "a player with all pieces in goal area gets skipped" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 27, player_color: :red},
        %{area: :goal, position_index: 3, player_color: :blue},
        %{area: :goal, position_index: 2, player_color: :blue},
        %{area: :goal, position_index: 1, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :home, position_index: 0, player_color: :yellow}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {game_state, _changes} = Logic.execute_move(game_state, move)

    assert %{current_player: :yellow, roll: nil, roll_count: 0} = game_state
  end

  test "a player rolling a six can raise when criteria are met" do
    # Raising is available when a player
    # 1) Rolls a six on their turn,
    # 2) Has all pieces out of goal,
    # 3) And all players have at least one piece in goal

    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :red},
        %{area: :play, position_index: 2, player_color: :red},
        %{area: :play, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert 4 = length(moves)

    assert Enum.any?(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))
  end

  test "a player raising has their opponents' pieces move to first free home space and own piece to start space" do
    # Raising is available when a player
    # 1) Rolls a six on their turn,
    # 2) Has all pieces out of goal,
    # 3) And all players have at least one piece in goal

    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :red},
        %{area: :play, position_index: 2, player_color: :red},
        %{area: :play, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert 4 = length(moves)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {game_state, changes} = Logic.execute_move(game_state, move)

    assert %{current_player: :red, roll: nil, roll_count: 0} = game_state

    assert Enum.any?(
             game_state.pieces,
             &match?(%{position_index: 0, area: :play, player_color: :red}, &1)
           )

    assert %{animated_effects: effects} = changes
    assert length(effects) == 3

    assert Enum.all?(effects, &match?(%{target_area: :home, target_index: 0}, &1))
  end

  test "a player raising can eat a piece in their starting space" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :red},
        %{area: :play, position_index: 2, player_color: :red},
        %{area: :play, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :green}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert 4 = length(moves)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {game_state, changes} = Logic.execute_move(game_state, move)

    assert %{current_player: :red, roll: nil, roll_count: 0} = game_state

    assert Enum.any?(
             game_state.pieces,
             &match?(%{position_index: 0, area: :play, player_color: :red}, &1)
           )

    assert %{animated_effects: effects} = changes
    assert length(effects) == 4

    assert Enum.any?(
             effects,
             &match?(%{target_area: :home, target_index: 1}, &1)
           )
  end

  test "a player raising can double a piece in their starting space" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 2, player_color: :red},
        %{area: :play, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {_game_state, changes} = Logic.execute_move(game_state, move)

    assert %{doubled: %{multiplier: 2}} = changes
  end

  test "a player can roll again if the only move available is a raise" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :play, position_index: 27, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    {:ok, game_state} = Logic.set_roll(game_state, 1)
    assert %{current_player: :red, roll_count: 1} = game_state
  end

  test "a player can raise if the only move available is a raise" do
    attrs = %{
      current_player: :red,
      roll: nil,
      roll_count: 0,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :play, position_index: 27, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    {:ok, game} = Logic.set_roll(game, 6)
    [%{type: "raise"} | []] = Logic.get_moves(game)
  end

  test "a piece getting eaten lists a penalty for the eaten player" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :blue}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {_game_state, changes} = Logic.execute_move(game_state, move)

    assert %{penalties: [%{player: :blue, amount: 1}]} = changes
  end

  test "listed penalty is equal to multiplier of eating piece times multiplier of target piece" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, player_color: :red, multiplier: 3},
        %{area: :play, position_index: 1, player_color: :blue, multiplier: 2},
        %{area: :center, position_index: 0, player_color: :blue},
        %{area: :center, position_index: 0, player_color: :red},
        %{area: :center, position_index: 1, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {_game_state, changes} = Logic.execute_move(game_state, move)

    assert %{penalties: [%{player: :blue, amount: 6}]} = changes
  end

  test "walking into a mine lists a penalty for the current player" do
    attrs = %{
      current_player: :red,
      roll: 1,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 6, player_color: :red, multiplier: 3},
        %{area: :play, position_index: 7, player_color: :blue, multiplier: 2},
        %{area: :center, position_index: 0, player_color: :blue},
        %{area: :center, position_index: 0, player_color: :red},
        %{area: :center, position_index: 1, player_color: :red}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game_state))

    {_game_state, changes} = Logic.execute_move(game_state, move)

    assert %{penalties: [%{player: :red, amount: 6}]} = changes
  end

  test "a piece eaten when raising causes a penalty" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :red},
        %{area: :play, position_index: 2, player_color: :red},
        %{area: :play, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :green}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    move = Enum.find(moves, &match?(%{target_index: 0, target_area: :play, type: "raise"}, &1))

    {_game_state, changes} = Logic.execute_move(game_state, move)

    assert %{penalties: [%{player: :green, amount: 1}]} = changes
  end

  test "a player moving last piece into goal with no penalties sets has_finished to true" do
    attrs = %{
      current_player: :red,
      roll: 4,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :play, position_index: 27, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {%{players: players}, _changes} = Logic.execute_move(game, move)

    assert Enum.any?(players, &match?(%{has_finished: true, color: :red}, &1))
  end

  test "a player finishing last penalty with all pieces in goal has_finished to true" do
    attrs = %{
      current_player: :red,
      roll: 4,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :goal, position_index: 3, player_color: :red}
      ],
      players: [
        %{color: :red, penalties: 1, name: "Player 1"}
      ]
    }

    assert %{players: [%{id: player_id, color: :red, has_finished: false}]} =
             game = TestHelpers.game_fixture(attrs)

    assert {:ok, %{players: [%{id: ^player_id, color: :red, has_finished: true}]}} =
             Logic.set_player_penalty(game, player_id, 0)
  end

  test "player with pieces in goal indices 0, 0, 2, 3 does not get has_finished set to true" do
    attrs = %{
      current_player: :red,
      roll: 4,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :play, position_index: 27, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    move = hd(Logic.get_moves(game))

    {%{players: players}, _changes} = Logic.execute_move(game, move)

    assert Enum.any?(players, &match?(%{has_finished: false, color: :red}, &1))
  end

  test "a player that has finished is not affected by a raise" do
    attrs = %{
      current_player: :blue,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :goal, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :play, position_index: 8, player_color: :blue},
        %{area: :play, position_index: 9, player_color: :blue},
        %{area: :play, position_index: 10, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :green}
      ],
      players: [
        %{color: :red, name: "Player 1", has_finished: true},
        %{color: :blue, name: "Player 2"},
        %{color: :yellow, name: "Player 3"},
        %{color: :green, name: "Player 4"}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {%{pieces: pieces}, _changes} = Logic.execute_move(game_state, move)

    red_pieces = pieces |> Enum.filter(fn p -> p.player_color == :red end)

    assert Enum.all?(
             red_pieces,
             &match?(%{area: :goal, player_color: :red}, &1)
           )
  end

  test "a player in goal with penalties remaining is affected by a raise" do
    attrs = %{
      current_player: :blue,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :goal, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :play, position_index: 8, player_color: :blue},
        %{area: :play, position_index: 9, player_color: :blue},
        %{area: :play, position_index: 10, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :green}
      ],
      players: [
        %{color: :red, name: "Player 1", penalties: 3},
        %{color: :blue, name: "Player 2"},
        %{color: :yellow, name: "Player 3"},
        %{color: :green, name: "Player 4"}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {%{pieces: pieces}, _changes} = Logic.execute_move(game_state, move)

    red_pieces = pieces |> Enum.filter(fn p -> p.player_color == :red end)

    assert Enum.any?(
             red_pieces,
             &match?(%{area: :home, player_color: :red}, &1)
           )
  end

  test "a player cannot raise if they have can_raise set to false" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :play, position_index: 0, player_color: :red},
        %{area: :goal, position_index: 1, player_color: :red},
        %{area: :goal, position_index: 2, player_color: :red},
        %{area: :goal, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :play, position_index: 8, player_color: :blue},
        %{area: :play, position_index: 9, player_color: :blue},
        %{area: :play, position_index: 10, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green},
        %{area: :play, position_index: 0, player_color: :green}
      ],
      players: [
        %{color: :red, name: "Player 1", can_raise: false},
        %{color: :blue, name: "Player 2"},
        %{color: :yellow, name: "Player 3"},
        %{color: :green, name: "Player 4"}
      ]
    }

    game_state = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game_state)

    assert !Enum.any?(moves, &match?(%{type: "raise"}, &1))
  end

  test "can_raise is set to false after a player raises" do
    attrs = %{
      current_player: :red,
      roll: 6,
      roll_count: 1,
      pieces: [
        %{area: :goal, position_index: 0, player_color: :red},
        %{area: :play, position_index: 1, player_color: :red},
        %{area: :play, position_index: 2, player_color: :red},
        %{area: :play, position_index: 3, player_color: :red},
        %{area: :goal, position_index: 0, player_color: :blue},
        %{area: :goal, position_index: 0, player_color: :yellow},
        %{area: :goal, position_index: 0, player_color: :green}
      ]
    }

    game = TestHelpers.game_fixture(attrs)

    moves = Logic.get_moves(game)

    move = Enum.find(moves, &match?(%{type: "raise"}, &1))

    {game, _changes} = Logic.execute_move(game, move)

    %{players: players} = game

    player = Enum.find(players, &match?(%{color: :red}, &1))
    assert player.can_raise == false
  end

  test "player can agree to a new raising round" do
    attrs = %{
      players: [
        %{name: "Player 1", color: :red, can_raise: false},
        %{name: "Player 2", color: :blue}
      ]
    }

    game = TestHelpers.game_fixture(attrs)
    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    assert %{players: players} = Logic.agree_to_new_raise(game, player, true)

    assert players |> Enum.any?(&match?(%{new_raising_round: true, color: :red}, &1))
  end

  test "player can draw back agreement to a new raising round" do
    game = TestHelpers.game_fixture()
    player = Enum.find(game.players, &match?(%{color: :red}, &1))
    game = Logic.agree_to_new_raise(game, player, true)
    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    game = Logic.agree_to_new_raise(game, player, false)

    assert game.players |> Enum.all?(&match?(%{new_raising_round: false}, &1))
  end

  test "players can raise again after everyone agrees to a new raising round" do
    attrs = %{
      players: [
        %{name: "Player 1", color: :red, can_raise: false, new_raising_round: false},
        %{name: "Player 2", color: :blue, can_raise: false, new_raising_round: true},
        %{name: "Player 3", color: :yellow, can_raise: false, new_raising_round: true},
        %{name: "Player 4", color: :green, can_raise: false, new_raising_round: true}
      ]
    }

    game = TestHelpers.game_fixture(attrs)
    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    assert %{players: players} = Logic.agree_to_new_raise(game, player, true)

    assert players |> Enum.all?(&match?(%{new_raising_round: false, can_raise: true}, &1))
  end

  test "a player getting all pieces moved to home by getting eaten gets needs_hembo flag set to true" do
    attrs = %{
      current_player: :red,
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
      current_player: :red,
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
