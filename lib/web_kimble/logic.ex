defmodule WebKimble.Logic do
  alias WebKimble.Repo
  alias WebKimble.Logic.GameState
  alias WebKimble.Logic.Move
  alias WebKimble.Logic.Constants
  alias WebKimble.Logic.Piece

  def create_initial_game_state(game, attrs) do
    {:ok, state} = create_game_state(game, attrs)

    initial_pieces = WebKimble.Logic.Constants.initial_pieces()

    Enum.each(initial_pieces, fn p -> {:ok, _piece} = create_piece(state, p) end)

    {:ok, state}
  end

  def create_game_state(game, attrs) do
    %GameState{}
    |> GameState.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:game, game)
    |> Repo.insert()
  end

  def create_game_state(attrs) do
    %GameState{}
    |> GameState.changeset(attrs)
    |> Repo.insert()
  end

  def update_game_state(game_state, attrs) do
    game_state
    |> GameState.changeset(attrs)
    |> Repo.update()
  end

  def available_colors(taken_colors) when is_list(taken_colors) do
    Constants.player_colors()
    |> Enum.filter(fn c -> c not in taken_colors end)
  end

  defp has_movable_pieces_with_roll?(
         %GameState{current_player: current_player} = game_state,
         roll
       ) do
    game_state = Repo.preload(game_state, :pieces)

    current_player_pieces =
      game_state.pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)

    moves =
      current_player_pieces
      |> Enum.map(&get_piece_move(&1, roll))
      |> Enum.filter(fn m -> m != nil end)
      |> Enum.filter(fn m ->
        m.target_area != :goal || m.target_index < Constants.goal_track_length()
      end)
      |> Enum.filter(fn m ->
        !Enum.any?(
          current_player_pieces,
          fn p -> p.area == m.target_area && p.position_index == m.target_index end
        )
      end)

    length(moves) > 0
  end

  defp has_movable_pieces_in_play?(%GameState{current_player: current_player} = game_state) do
    game_state = Repo.preload(game_state, :pieces)

    pieces_in_play =
      game_state.pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)
      |> Enum.filter(fn p -> p.area == :play end)

    length(pieces_in_play) > 0
  end

  defp has_movable_pieces_in_goal?(%GameState{current_player: current_player} = game_state) do
    game_state = Repo.preload(game_state, :pieces)

    pieces_in_goal =
      game_state.pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)
      |> Enum.filter(fn p -> p.area == :goal end)

    indices = Enum.map(pieces_in_goal, fn p -> p.position_index end)

    free_indices = Enum.filter(0..3, fn i -> !Enum.any?(indices, fn j -> j == i end) end)
    max_free_index = Enum.max(free_indices)

    movable_pieces = Enum.filter(pieces_in_goal, fn p -> p.position_index < max_free_index end)

    length(movable_pieces) > 0
  end

  def set_roll(
        %GameState{roll: previous_roll, current_player: current_player, roll_count: roll_count} =
          game_state,
        roll
      )
      when previous_roll == 0 or previous_roll == nil do
    if has_movable_pieces_with_roll?(game_state, roll) do
      update_game_state(game_state, %{roll: roll, roll_count: roll_count + 1})
    else
      cond do
        roll == 6 ->
          update_game_state(game_state, %{
            roll: nil,
            current_player: current_player,
            roll_count: 0
          })

        roll_count + 1 < Constants.max_rolls() && !has_movable_pieces_in_play?(game_state) &&
            !has_movable_pieces_in_goal?(game_state) ->
          update_game_state(game_state, %{
            roll: nil,
            current_player: current_player,
            roll_count: roll_count + 1
          })

        true ->
          update_game_state(game_state, %{
            roll: nil,
            roll_count: 0,
            current_player: get_next_player(game_state)
          })
      end
    end
  end

  def set_roll(%GameState{} = _game_state, _roll) do
    {:error, "Roll needs to be used before rolling again"}
  end

  defp home_to_play_move(%Piece{} = piece) do
    %Move{
      piece_id: piece.id,
      target_area: :play,
      target_index: Constants.get_home_space_index(piece.player_color)
    }
  end

  defp in_play_move(%Piece{} = piece, roll) do
    home_index = Constants.get_home_space_index(piece.player_color)

    sum = piece.position_index + roll

    temp_steps = piece.position_index - home_index

    steps_taken =
      if temp_steps < 0 do
        temp_steps + Constants.play_track_length()
      else
        temp_steps
      end

    target_index = rem(sum, Constants.play_track_length())

    if steps_taken + roll < Constants.play_track_length() do
      %Move{
        piece_id: piece.id,
        target_area: :play,
        target_index: target_index
      }
    else
      diff = target_index - home_index

      %Move{
        piece_id: piece.id,
        target_area: :goal,
        target_index: diff
      }
    end
  end

  defp in_goal_move(%Piece{} = piece, roll) when roll in 1..6 do
    %Move{
      piece_id: piece.id,
      target_area: :goal,
      target_index: piece.position_index + roll
    }
  end

  defp get_piece_move(%Piece{} = piece, roll) when roll in 1..6 do
    case piece.area do
      :home ->
        if roll == 6 do
          home_to_play_move(piece)
        else
          nil
        end

      :play ->
        in_play_move(piece, roll)

      :goal ->
        in_goal_move(piece, roll)

      _ ->
        nil
    end
  end

  defp move_is_into_mine?(%Move{} = move, current_player, pieces) do
    target_piece =
      Enum.find(pieces, fn p ->
        p.area == move.target_area && p.position_index == move.target_index
      end)

    case target_piece do
      nil ->
        false

      %Piece{player_color: ^current_player} ->
        false

      %Piece{area: :play, position_index: index, player_color: color} ->
        index == Constants.get_home_space_index(color)

      _piece ->
        false
    end
  end

  def get_moves(%GameState{roll: roll, current_player: current_player} = game_state)
      when roll in 1..6 do
    game_state = Repo.preload(game_state, :pieces)

    current_player_pieces =
      game_state.pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)

    moves =
      current_player_pieces
      |> Enum.map(&get_piece_move(&1, roll))
      |> Enum.filter(fn m -> m != nil end)
      |> Enum.filter(fn m ->
        m.target_area != :goal || m.target_index < Constants.goal_track_length()
      end)
      |> Enum.filter(fn m ->
        !Enum.any?(
          current_player_pieces,
          fn p ->
            roll != 6 && p.position_index != Constants.get_home_space_index(p.player_color) &&
              (p.area == m.target_area && p.position_index == m.target_index)
          end
        )
      end)

    non_mine_moves =
      moves |> Enum.filter(fn m -> !move_is_into_mine?(m, current_player, game_state.pieces) end)

    if length(non_mine_moves) > 0 do
      non_mine_moves
    else
      moves
    end
  end

  def get_moves(%GameState{roll: nil} = _game_state) do
    []
  end

  def get_moves(%GameState{roll: 0} = _game_state) do
    []
  end

  def create_piece(%GameState{} = game_state, attrs) do
    %Piece{}
    |> Piece.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:game_state, game_state)
    |> Repo.insert()
  end

  def get_piece(id) do
    Repo.get(Piece, id)
  end

  def update_piece(%Piece{} = piece, attrs) do
    piece
    |> Piece.changeset(attrs)
    |> Repo.update()
  end

  def random_player() do
    Enum.random(Constants.player_colors())
  end

  defp get_next_player(%GameState{roll: roll} = game_state) do
    case roll do
      6 -> game_state.current_player
      _ -> Constants.next_player(game_state.current_player)
    end
  end

  defp handle_eaten_piece(game_state, piece) do
    player_home_pieces =
      game_state.pieces
      |> Enum.filter(fn p ->
        p.player_color == piece.player_color and p.area == :home
      end)

    free_home_indices =
      0..3
      |> Enum.filter(fn i ->
        !Enum.any?(player_home_pieces, fn p -> p.position_index == i end)
      end)

    [first_free_home_index | remaining_free_home_indices] = free_home_indices

    eaten_array = [
      %{
        piece_id: piece.id,
        target_area: :home,
        target_index: first_free_home_index,
        start_area: piece.area,
        start_index: piece.position_index
      }
    ]

    eaten_array =
      if piece.multiplier > 1 do
        center_pieces =
          game_state.pieces
          |> Enum.filter(fn p -> p.player_color == piece.player_color and p.area == :center end)

        eaten_center_pieces =
          1..(piece.multiplier - 1)
          |> Enum.map(fn i -> {i, Enum.at(center_pieces, -i)} end)
          |> Enum.map(fn {i, p} ->
            {p,
             %{
               piece_id: p.id,
               target_area: :home,
               target_index: Enum.at(remaining_free_home_indices, i - 1),
               start_area: p.area,
               start_index: p.position_index
             }}
          end)

        eaten_center_pieces
        |> Enum.each(fn {p, eaten} ->
          {:ok, _p} =
            update_piece(p, %{
              area: :home,
              position_index: eaten.target_index,
              multiplied: 1
            })
        end)

        eaten_center_pieces =
          eaten_center_pieces
          |> Enum.map(fn {_p, eaten} -> eaten end)

        eaten_array ++ eaten_center_pieces
      else
        eaten_array
      end

    {:ok, _piece} =
      update_piece(piece, %{area: :home, position_index: first_free_home_index, multiplier: 1})

    eaten_array
  end

  def execute_move(%GameState{} = game_state, move) do
    piece = get_piece(move.piece_id)

    game_state = Repo.preload(game_state, :pieces)

    target_piece =
      Enum.find(game_state.pieces, fn p ->
        p.position_index == move.target_index and move.target_area == :play and
          p.area == :play
      end)

    changes =
      if target_piece != nil do
        if target_piece.player_color == piece.player_color do
          player_center_piece_indices =
            game_state.pieces
            |> Enum.filter(fn p -> p.player_color == piece.player_color end)
            |> Enum.filter(fn p -> p.area == :center end)
            |> Enum.map(fn p -> p.position_index end)

          free_center_index =
            0..2
            |> Enum.find(fn i -> !Enum.any?(player_center_piece_indices, fn j -> i == j end) end)

          {:ok, doubled_piece} =
            update_piece(target_piece, %{multiplier: target_piece.multiplier + 1})

          {:ok, moved_piece} =
            update_piece(piece, %{area: :center, position_index: free_center_index})

          %{
            move: %{
              piece_id: move.piece_id,
              target_area: moved_piece.area,
              target_index: moved_piece.position_index,
              start_area: piece.area,
              start_index: piece.position_index
            },
            doubled: %{
              piece_id: doubled_piece.id,
              multiplier: doubled_piece.multiplier
            }
          }
        else
          if target_piece.position_index ==
               Constants.get_home_space_index(target_piece.player_color) do
            %{
              move: %{
                piece_id: move.piece_id,
                target_area: move.target_area,
                target_index: move.target_index,
                start_area: piece.area,
                start_index: piece.position_index
              },
              eaten:
                handle_eaten_piece(game_state, %Piece{
                  id: piece.id,
                  position_index: target_piece.position_index,
                  area: piece.area,
                  player_color: piece.player_color,
                  multiplier: piece.multiplier
                })
            }
          else
            {:ok, _piece} =
              update_piece(piece, %{area: move.target_area, position_index: move.target_index})

            %{
              move: %{
                piece_id: move.piece_id,
                target_area: move.target_area,
                target_index: move.target_index,
                start_area: piece.area,
                start_index: piece.position_index
              },
              eaten: handle_eaten_piece(game_state, target_piece)
            }
          end
        end
      else
        if piece.multiplier > 1 and move.target_area == :goal do
          num_promoted_pieces = piece.multiplier - 1

          promoted_pieces =
            game_state.pieces
            |> Enum.filter(fn p -> p.player_color == piece.player_color end)
            |> Enum.filter(fn p -> p.area == :center end)
            |> Enum.take(num_promoted_pieces)

          Enum.each(promoted_pieces, fn p ->
            {:ok, _piece} = update_piece(p, %{area: :goal, position_index: 0})
          end)

          promoted =
            promoted_pieces
            |> Enum.map(fn p ->
              %{
                start_area: p.area,
                start_index: p.position_index,
                piece_id: p.id,
                target_area: :goal,
                target_index: 0
              }
            end)

          {:ok, _piece} =
            update_piece(piece, %{
              area: move.target_area,
              position_index: move.target_index,
              multiplier: 1
            })

          %{
            move: %{
              piece_id: move.piece_id,
              target_area: move.target_area,
              target_index: move.target_index,
              start_area: piece.area,
              start_index: piece.position_index
            },
            doubled: %{
              piece_id: move.piece_id,
              multiplier: 1
            },
            promoted: promoted
          }
        else
          {:ok, _piece} =
            update_piece(piece, %{area: move.target_area, position_index: move.target_index})

          %{
            move: %{
              piece_id: move.piece_id,
              target_area: move.target_area,
              target_index: move.target_index,
              start_area: piece.area,
              start_index: piece.position_index
            }
          }
        end
      end

    next_player = get_next_player(game_state)

    {:ok, game_state} =
      update_game_state(game_state, %{current_player: next_player, roll: nil, roll_count: 0})

    game_state = game_state |> Repo.preload(:pieces, force: true)

    {game_state, changes}
  end
end
