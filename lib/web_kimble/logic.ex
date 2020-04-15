defmodule WebKimble.Logic do
  alias WebKimble.Repo
  alias WebKimble.Logic.Move
  alias WebKimble.Logic.Constants
  alias WebKimble.Logic.Piece
  alias WebKimble.Logic.Game
  alias WebKimble.Logic.Player

  def create_game(attrs) do
    %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  def update_game(game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  def available_colors(taken_colors) when is_list(taken_colors) do
    Constants.player_colors()
    |> Enum.filter(fn c -> c not in taken_colors end)
  end

  defp has_movable_pieces_with_roll?(
         %Game{current_player: current_player} = game,
         roll
       ) do
    game = Repo.preload(game, :pieces)

    current_player_pieces =
      game.pieces
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

  defp has_movable_pieces?(%Game{} = game, color) do
    game = Repo.preload(game, :pieces)

    goal_piece_indices =
      game.pieces
      |> Enum.filter(fn p -> p.player_color == color end)
      |> Enum.filter(fn p -> p.area == :goal end)
      |> Enum.map(fn p -> p.position_index end)
      |> Enum.sort()

    goal_piece_indices != Enum.to_list(0..3)
  end

  defp has_movable_pieces_in_play?(%Game{current_player: current_player} = game) do
    game = Repo.preload(game, :pieces)

    pieces_in_play =
      game.pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)
      |> Enum.filter(fn p -> p.area == :play end)

    length(pieces_in_play) > 0
  end

  defp has_movable_pieces_in_goal?(%Game{current_player: current_player} = game) do
    game = Repo.preload(game, :pieces)

    pieces_in_goal =
      game.pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)
      |> Enum.filter(fn p -> p.area == :goal end)

    indices = Enum.map(pieces_in_goal, fn p -> p.position_index end)

    free_indices = Enum.filter(0..3, fn i -> !Enum.any?(indices, fn j -> j == i end) end)
    max_free_index = Enum.max(free_indices)

    movable_pieces = Enum.filter(pieces_in_goal, fn p -> p.position_index < max_free_index end)

    length(movable_pieces) > 0
  end

  defp set_roll_internal(
         %Game{current_player: current_player, roll_count: roll_count} = game,
         roll
       ) do
    if has_movable_pieces_with_roll?(game, roll) do
      update_game(game, %{roll: roll, roll_count: roll_count + 1})
    else
      cond do
        roll == 6 ->
          update_game(game, %{
            roll: nil,
            current_player: current_player,
            roll_count: 0
          })

        roll_count + 1 < Constants.max_rolls() && !has_movable_pieces_in_play?(game) &&
            !has_movable_pieces_in_goal?(game) ->
          update_game(game, %{
            roll: nil,
            current_player: current_player,
            roll_count: roll_count + 1
          })

        true ->
          update_game(game, %{
            roll: nil,
            roll_count: 0,
            current_player: get_next_player(game)
          })
      end
    end
  end

  def set_roll(%Game{roll: previous_roll} = game, roll)
      when previous_roll == 0 or previous_roll == nil do
    set_roll_internal(game, roll)
  end

  def set_roll(%Game{} = game, roll) do
    moves = get_moves(game)

    if Enum.any?(moves, &match?(%{type: "move"}, &1)) do
      {:error, "Roll needs to be used before rolling again"}
    else
      set_roll_internal(Map.put(game, :roll_count, 0), roll)
    end
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

  defp move_is_into_mine?(%Move{type: "raise"}, _current_player, _pieces) do
    false
  end

  defp move_is_into_mine?(%Move{type: "move"} = move, current_player, pieces) do
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

  defp get_goal_pieces_by_player(%Game{pieces: pieces}) do
    pieces
    |> Enum.filter(fn p -> p.area == :goal end)
    |> Enum.group_by(fn p -> p.player_color end)
  end

  defp get_first_goal_pieces(%Game{} = game) do
    get_goal_pieces_by_player(game)
    |> Enum.map(fn {k, v} -> {k, Enum.sort_by(v, fn p -> p.position_index end)} end)
    |> Enum.map(fn {k, v} -> {k, hd(v)} end)
  end

  defp get_potential_raise(
         %Game{roll: roll, current_player: current_player, pieces: pieces, players: players} =
           game
       )
       when roll == 6 do
    current_player_home_pieces =
      pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)
      |> Enum.filter(fn p -> p.area == :home end)

    goal_pieces = get_first_goal_pieces(game)
    raised_piece = goal_pieces[current_player]

    player = players |> Enum.find(fn p -> p.color == current_player end)

    cond do
      raised_piece == nil ->
        []

      !player.can_raise ->
        []

      length(current_player_home_pieces) > 0 ->
        []

      length(goal_pieces) < Constants.player_count() ->
        []

      true ->
        piece = goal_pieces[current_player]

        [
          %Move{
            piece_id: piece.id,
            target_index: Constants.get_home_space_index(current_player),
            target_area: :play,
            type: "raise"
          }
        ]
    end
  end

  defp get_potential_raise(%Game{roll: roll} = _game) when roll != 6 do
    []
  end

  def get_moves(%Game{roll: roll, current_player: current_player} = game)
      when roll in 1..6 do
    game = game |> Repo.preload(:pieces) |> Repo.preload(:players)

    current_player_pieces =
      game.pieces
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

    potential_raise = get_potential_raise(game)
    moves = moves ++ potential_raise

    non_mine_moves =
      moves |> Enum.filter(fn m -> !move_is_into_mine?(m, current_player, game.pieces) end)

    if length(non_mine_moves) > 0 do
      non_mine_moves
    else
      moves
    end
  end

  def get_moves(%Game{roll: nil} = _game) do
    []
  end

  def get_moves(%Game{roll: 0} = _game) do
    []
  end

  def create_piece(%Game{} = game, attrs) do
    %Piece{}
    |> Piece.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:game, game)
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

  defp next_player_recurse(game, player) do
    cond do
      has_movable_pieces?(game, player) ->
        player

      true ->
        next_player_recurse(game, Constants.next_player(player), player)
    end
  end

  defp next_player_recurse(game, player, initial_player) do
    cond do
      player == initial_player ->
        :none

      has_movable_pieces?(game, player) ->
        player

      true ->
        next_player_recurse(game, Constants.next_player(player), initial_player)
    end
  end

  defp get_next_player(%Game{roll: roll} = game) do
    next_player_candidate =
      case roll do
        6 -> game.current_player
        _ -> Constants.next_player(game.current_player)
      end

    next_player_recurse(game, next_player_candidate)
  end

  defp get_first_free_home_index(game, player_color) do
    player_home_pieces =
      game.pieces
      |> Enum.filter(fn p ->
        p.player_color == player_color and p.area == :home
      end)

    0..3
    |> Enum.filter(fn i ->
      !Enum.any?(player_home_pieces, fn p -> p.position_index == i end)
    end)
    |> Enum.take(1)
    |> hd
  end

  defp handle_demoted_pieces(game, demoted_pieces) do
    piece_index_tuples =
      demoted_pieces
      |> Enum.map(fn p -> {p, get_first_free_home_index(game, p.player_color)} end)

    piece_index_tuples
    |> Enum.each(fn {p, home_index} ->
      {:ok, _piece} = update_piece(p, %{area: :home, position_index: home_index, multiplier: 1})
    end)

    piece_index_tuples
    |> Enum.map(fn {p, home_index} ->
      %{
        piece_id: p.id,
        target_area: :home,
        target_index: home_index,
        start_area: p.area,
        start_index: p.position_index
      }
    end)
  end

  defp handle_eaten_piece(game, piece) do
    player_home_pieces =
      game.pieces
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
          game.pieces
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

  defp check_game_end(%Game{pieces: pieces, players: players} = game) do
    players
    |> Enum.filter(fn p -> p.penalties == 0 end)
    |> Enum.filter(fn pl ->
      player_goal_pieces =
        pieces
        |> Enum.filter(fn pc -> pc.player_color == pl.color end)
        |> Enum.filter(fn pc -> pc.area == :goal end)

      length(player_goal_pieces) == Constants.player_piece_count()
    end)
    |> Enum.each(fn p ->
      update_player(p, %{has_finished: true})
    end)

    game |> Repo.preload(:players, force: true)
  end

  def execute_move(
        %Game{current_player: current_player} = game,
        %Move{type: type} = move
      ) do
    piece = get_piece(move.piece_id)

    game = game |> Repo.preload(:pieces) |> Repo.preload(:players)

    target_piece =
      Enum.find(game.pieces, fn p ->
        p.position_index == move.target_index and move.target_area == :play and
          p.area == :play
      end)

    changes =
      if target_piece != nil do
        if target_piece.player_color == piece.player_color do
          player_center_piece_indices =
            game.pieces
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
              animated_effects:
                handle_eaten_piece(game, %Piece{
                  id: piece.id,
                  position_index: target_piece.position_index,
                  area: piece.area,
                  player_color: piece.player_color,
                  multiplier: piece.multiplier
                }),
              penalties: [
                %{
                  player: piece.player_color,
                  amount: target_piece.multiplier * piece.multiplier
                }
              ]
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
              animated_effects: handle_eaten_piece(game, target_piece),
              penalties: [
                %{
                  player: target_piece.player_color,
                  amount: target_piece.multiplier * piece.multiplier
                }
              ]
            }
          end
        end
      else
        if piece.multiplier > 1 and move.target_area == :goal do
          num_promoted_pieces = piece.multiplier - 1

          promoted_pieces =
            game.pieces
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
            animated_effects: promoted
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

    changes =
      if type == "raise" do
        # Updates the possible previously eaten piece so we have an accurate representation of the free spaces
        game = game |> Repo.preload(:pieces, force: true)

        finished_players = game.players |> Enum.filter(fn p -> p.has_finished end)

        demoted_pieces =
          get_first_goal_pieces(game)
          |> Enum.filter(fn {c, _p} -> c != current_player end)
          |> Enum.filter(fn {c, _p} -> !Enum.any?(finished_players, fn p -> p.color == c end) end)
          |> Enum.map(fn {_c, p} -> p end)

        demoted =
          handle_demoted_pieces(game, demoted_pieces) ++
            Map.get(changes, :animated_effects, [])

        player = game.players |> Enum.find(fn p -> p.color == current_player end)
        {:ok, _player} = update_player(player, %{can_raise: false})

        Map.put(changes, :animated_effects, demoted)
      else
        changes
      end

    game = check_game_end(game |> Repo.preload(:pieces, force: true))

    next_player = get_next_player(game)

    {:ok, game} = update_game(game, %{current_player: next_player, roll: nil, roll_count: 0})

    game = game |> Repo.preload(:pieces, force: true)

    {game, changes}
  end

  def get_game_by(attrs) do
    game = Repo.get_by(Game, attrs)

    case game do
      nil -> {:error, "Game not found"}
      game -> {:ok, game}
    end
  end

  defp preload_game(game, opts \\ []) when is_list(opts) do
    game =
      game
      |> Repo.preload(:pieces, opts)
      |> Repo.preload(:players, opts)

    sorted_players = Enum.sort_by(game.players, fn p -> p.inserted_at end, NaiveDateTime)
    %Game{game | players: sorted_players}
  end

  def get_game_by_code(code) do
    case get_game_by(%{code: code}) do
      {:error, message} -> {:error, message}
      {:ok, game} -> {:ok, preload_game(game)}
    end
  end

  def create_game_with_initial_state(attrs) do
    attrs = Map.put(attrs, :current_player, WebKimble.Logic.random_player())

    # IO.inspect(attrs)
    case create_game(attrs) do
      {:ok, game} ->
        WebKimble.Logic.Constants.initial_pieces()
        |> Enum.each(fn p -> {:ok, _piece} = create_piece(game, p) end)

        {:ok, game}

      resp ->
        # IO.inspect(resp)
        resp
    end
  end

  def list_games() do
    Repo.all(Game)
  end

  def create_player(game, attrs) do
    {:ok, _player} =
      %Player{}
      |> Player.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:game, game)
      |> Repo.insert()
  end

  def get_player(id) do
    Repo.get(Player, id)
  end

  def update_player(player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  def set_player_penalty(%Game{} = game, player_id, amount) do
    case update_player(get_player(player_id), %{penalties: amount}) do
      {:ok, _player} ->
        {:ok,
         check_game_end(game |> Repo.preload(:pieces) |> Repo.preload(:players, force: true))}

      {:error, error} ->
        {:error, error}
    end
  end

  def apply_penalties(%Game{players: players} = game, penalties) do
    penalties
    |> Enum.each(fn p ->
      player = Enum.find(players, fn pl -> pl.color == p.player end)
      set_player_penalty(game, player.id, player.penalties + p.amount)
    end)

    Repo.preload(game, :players, force: true)
  end

  def join_game(code, name) do
    {:ok, game} = get_game_by(%{code: code})

    game = Repo.preload(game, :players)
    taken_colors = game.players |> Enum.map(fn p -> p.color end)
    available_colors = available_colors(taken_colors)

    case length(available_colors) do
      n when n > 0 ->
        {:ok, player} = create_player(game, %{name: name, color: Enum.random(available_colors)})
        {:ok, player, preload_game(game, force: true)}

      _ ->
        {:error, "Game is full"}
    end
  end

  def agree_to_new_raise(%Game{players: players} = game, player_color) do
    Repo.preload(game, :players)

    player = players |> Enum.find(fn p -> p.color == player_color end)

    update_player(player, %{new_raising_round: true})
    Repo.preload(game, :players, force: true)
  end
end
