defmodule WebLudo.Logic do
  alias WebLudo.Repo
  alias WebLudo.Logic.Move
  alias WebLudo.Logic.Constants
  alias WebLudo.Logic.Piece
  alias WebLudo.Logic.Game
  alias WebLudo.Logic.Player
  alias WebLudo.Logic.Team

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
    Constants.team_colors()
    |> Enum.filter(fn c -> c not in taken_colors end)
  end

  defp has_movable_pieces_with_roll?(
         %Game{current_team: current_team} = game,
         roll
       ) do
    moves = get_available_moves_for_team_with_roll(game, roll, current_team)

    length(moves) > 0
  end

  defp has_movable_pieces?(%Game{} = game, color) do
    game = Repo.preload(game, :pieces)

    goal_piece_indices =
      game.pieces
      |> Enum.filter(fn p -> p.team_color == color end)
      |> Enum.filter(fn p -> p.area == :goal end)
      |> Enum.map(fn p -> p.position_index end)
      |> Enum.sort()

    goal_piece_indices != Enum.to_list(0..3)
  end

  defp has_movable_pieces_in_play?(%Game{current_team: current_team} = game) do
    game = Repo.preload(game, :pieces)

    pieces_in_play =
      game.pieces
      |> Enum.filter(fn p -> p.team_color == current_team end)
      |> Enum.filter(fn p -> p.area == :play end)

    length(pieces_in_play) > 0
  end

  defp has_movable_pieces_in_goal?(%Game{current_team: current_team} = game) do
    game = Repo.preload(game, :pieces)

    pieces_in_goal =
      game.pieces
      |> Enum.filter(fn p -> p.team_color == current_team end)
      |> Enum.filter(fn p -> p.area == :goal end)

    indices = Enum.map(pieces_in_goal, fn p -> p.position_index end)

    free_indices = Enum.filter(0..3, fn i -> !Enum.any?(indices, fn j -> j == i end) end)
    max_free_index = Enum.max(free_indices)

    movable_pieces = Enum.filter(pieces_in_goal, fn p -> p.position_index < max_free_index end)

    length(movable_pieces) > 0
  end

  defp set_roll_internal(
         %Game{current_team: current_team, roll_count: roll_count} = game,
         roll
       ) do
    game = game |> Repo.preload(:pieces) |> Repo.preload(:players)

    if has_movable_pieces_with_roll?(game, roll) do
      update_game(game, %{roll: roll, roll_count: roll_count + 1})
    else
      cond do
        roll == 6 ->
          update_game(game, %{
            roll: nil,
            current_team: current_team,
            roll_count: 0
          })

        roll_count + 1 < Constants.max_rolls() && !has_movable_pieces_in_play?(game) &&
            !has_movable_pieces_in_goal?(game) ->
          update_game(game, %{
            roll: nil,
            current_team: current_team,
            roll_count: roll_count + 1
          })

        true ->
          update_game(game, %{
            roll: nil,
            roll_count: 0,
            current_team: get_next_team(game)
          })
      end
    end
  end

  def set_roll(%Game{has_started: false}, _roll) do
    {:error, "Cannot roll during setup"}
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
      target_index: Constants.get_home_space_index(piece.team_color)
    }
  end

  defp in_play_move(%Piece{} = piece, roll) do
    home_index = Constants.get_home_space_index(piece.team_color)

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

  defp move_is_into_mine?(%Move{type: "raise"}, _current_team, _pieces) do
    false
  end

  defp move_is_into_mine?(%Move{type: "move"} = move, current_team, pieces) do
    target_piece =
      Enum.find(pieces, fn p ->
        p.area == move.target_area && p.position_index == move.target_index
      end)

    case target_piece do
      nil ->
        false

      %Piece{team_color: ^current_team} ->
        false

      %Piece{area: :play, position_index: index, team_color: color} ->
        index == Constants.get_home_space_index(color)

      _piece ->
        false
    end
  end

  defp get_goal_pieces_by_team(%Game{pieces: pieces}) do
    pieces
    |> Enum.filter(fn p -> p.area == :goal end)
    |> Enum.group_by(fn p -> p.team_color end)
  end

  defp get_first_goal_pieces(%Game{} = game) do
    get_goal_pieces_by_team(game)
    |> Enum.map(fn {k, v} -> {k, Enum.sort_by(v, fn p -> p.position_index end)} end)
    |> Enum.map(fn {k, v} -> {k, hd(v)} end)
  end

  defp get_potential_raise(
         %Game{roll: roll, current_team: current_team, pieces: pieces, teams: teams} = game
       )
       when roll == 6 do
    current_team_home_pieces =
      pieces
      |> Enum.filter(fn p -> p.team_color == current_team end)
      |> Enum.filter(fn p -> p.area == :home end)

    goal_pieces = get_first_goal_pieces(game)
    raised_piece = goal_pieces[current_team]

    team = teams |> Enum.find(fn p -> p.color == current_team end)

    cond do
      raised_piece == nil ->
        []

      !team.can_raise ->
        []

      length(current_team_home_pieces) > 0 ->
        []

      length(goal_pieces) < Constants.team_count() ->
        []

      true ->
        piece = goal_pieces[current_team]

        [
          %Move{
            piece_id: piece.id,
            target_index: Constants.get_home_space_index(current_team),
            target_area: :play,
            type: "raise"
          }
        ]
    end
  end

  defp get_potential_raise(%Game{roll: roll} = _game) when roll != 6 do
    []
  end

  defp is_move_onto_given_pieces?(pieces, move) do
    Enum.any?(
      pieces,
      fn p ->
        p.area == move.target_area && p.position_index == move.target_index
      end
    )
  end

  defp can_move_double?(move, roll, team_color) do
    roll == 6 && move.target_index == Constants.get_home_space_index(team_color) &&
      move.target_area == :play
  end

  defp get_available_moves_for_team_with_roll(%Game{pieces: pieces} = game, roll, team_color)
       when roll in 1..6 do
    team_pieces =
      pieces
      |> Enum.filter(fn p -> p.team_color == team_color end)

    moves =
      team_pieces
      |> Enum.map(&get_piece_move(&1, roll))
      |> Enum.filter(fn m -> m != nil end)
      |> Enum.filter(fn m ->
        m.target_area != :goal || m.target_index < Constants.goal_track_length()
      end)
      |> Enum.filter(fn m ->
        !is_move_onto_given_pieces?(team_pieces, m) || can_move_double?(m, roll, team_color)
      end)

    potential_raise = get_potential_raise(Map.put(game, :roll, roll))
    moves = moves ++ potential_raise

    non_mine_moves = moves |> Enum.filter(fn m -> !move_is_into_mine?(m, team_color, pieces) end)

    if length(non_mine_moves) > 0 do
      non_mine_moves
    else
      moves
    end
  end

  def get_moves(%Game{has_started: false}) do
    []
  end

  def get_moves(%Game{roll: roll, current_team: current_team} = game)
      when roll in 1..6 do
    game = game |> Repo.preload(:pieces) |> Repo.preload(:players)

    get_available_moves_for_team_with_roll(game, roll, current_team)
  end

  def get_moves(%Game{roll: nil}) do
    []
  end

  def get_moves(%Game{roll: 0}) do
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

  def random_team() do
    Enum.random(Constants.team_colors())
  end

  defp next_team_recurse(game, team) do
    cond do
      has_movable_pieces?(game, team) ->
        team

      true ->
        next_team_recurse(game, Constants.next_team(team), team)
    end
  end

  defp next_team_recurse(game, team, initial_team) do
    cond do
      team == initial_team ->
        :none

      has_movable_pieces?(game, team) ->
        team

      true ->
        next_team_recurse(game, Constants.next_team(team), initial_team)
    end
  end

  defp get_next_team(%Game{roll: roll} = game) do
    next_team_candidate =
      case roll do
        6 -> game.current_team
        _ -> Constants.next_team(game.current_team)
      end

    next_team_recurse(game, next_team_candidate)
  end

  defp get_first_free_home_index(game, team_color) do
    team_home_pieces =
      game.pieces
      |> Enum.filter(fn p ->
        p.team_color == team_color and p.area == :home
      end)

    0..3
    |> Enum.filter(fn i ->
      !Enum.any?(team_home_pieces, fn p -> p.position_index == i end)
    end)
    |> Enum.take(1)
    |> hd
  end

  defp handle_demoted_pieces(game, demoted_pieces) do
    piece_index_tuples =
      demoted_pieces
      |> Enum.map(fn p -> {p, get_first_free_home_index(game, p.team_color)} end)

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
    team_home_pieces =
      game.pieces
      |> Enum.filter(fn p ->
        p.team_color == piece.team_color and p.area == :home
      end)

    free_home_indices =
      0..3
      |> Enum.filter(fn i ->
        !Enum.any?(team_home_pieces, fn p -> p.position_index == i end)
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
          |> Enum.filter(fn p -> p.team_color == piece.team_color and p.area == :center end)

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

  defp check_game_end(%Game{pieces: pieces, teams: teams} = game) do
    finishing_teams =
      teams
      |> Enum.filter(fn t -> t.penalties == 0 end)
      |> Enum.filter(fn t -> !t.has_finished end)
      |> Enum.filter(fn t ->
        team_goal_indices =
          pieces
          |> Enum.filter(fn pc -> pc.team_color == t.color end)
          |> Enum.filter(fn pc -> pc.area == :goal end)
          |> Enum.map(fn pc -> pc.position_index end)
          |> Enum.sort()

        team_goal_indices == Constants.goal_index_list()
      end)

    finishing_teams
    |> Enum.each(fn t ->
      update_team(t, %{has_finished: true})
    end)

    {game |> Repo.preload(:teams, force: true), Enum.map(finishing_teams, fn t -> t.color end)}
  end

  defp check_hembo(%Game{pieces: pieces, teams: teams} = game, %Game{pieces: initial_pieces}) do
    Constants.team_colors()
    |> Enum.filter(fn c ->
      team_home_pieces = Enum.filter(pieces, fn p -> p.area == :home && p.team_color == c end)

      length(team_home_pieces) == Constants.team_piece_count()
    end)
    |> Enum.filter(fn c ->
      team_home_pieces =
        Enum.filter(initial_pieces, fn p -> p.area == :home && p.team_color == c end)

      length(team_home_pieces) < Constants.team_piece_count()
    end)
    |> Enum.map(fn c -> Enum.find(teams, fn t -> t.color == c end) end)
    |> Enum.each(fn t -> update_team(t, %{needs_hembo: true}) end)

    game |> Repo.preload(:teams, force: true)
  end

  def execute_move(
        %Game{current_team: current_team} = game,
        %Move{type: type} = move
      ) do
    piece = get_piece(move.piece_id)

    game = game |> Repo.preload(:pieces) |> Repo.preload(:players)
    initial_game = game

    target_piece =
      Enum.find(game.pieces, fn p ->
        p.position_index == move.target_index and move.target_area == :play and
          p.area == :play
      end)

    changes =
      if target_piece != nil do
        if target_piece.team_color == piece.team_color do
          team_center_piece_indices =
            game.pieces
            |> Enum.filter(fn p -> p.team_color == piece.team_color end)
            |> Enum.filter(fn p -> p.area == :center end)
            |> Enum.map(fn p -> p.position_index end)

          free_center_index =
            0..2
            |> Enum.find(fn i -> !Enum.any?(team_center_piece_indices, fn j -> i == j end) end)

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
              multiplier: doubled_piece.multiplier,
              team: doubled_piece.team_color
            }
          }
        else
          if target_piece.position_index ==
               Constants.get_home_space_index(target_piece.team_color) do
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
                  team_color: piece.team_color,
                  multiplier: piece.multiplier
                }),
              penalties: [
                %{
                  team: piece.team_color,
                  amount: target_piece.multiplier * piece.multiplier,
                  eaten: Constants.piece_name(piece.multiplier),
                  eater: Constants.piece_name(target_piece.multiplier),
                  type: "mine"
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
                  team: target_piece.team_color,
                  amount: target_piece.multiplier * piece.multiplier,
                  eaten: Constants.piece_name(target_piece.multiplier),
                  eater: Constants.piece_name(piece.multiplier),
                  type: "eat"
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
            |> Enum.filter(fn p -> p.team_color == piece.team_color end)
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

        finished_teams = game.teams |> Enum.filter(fn p -> p.has_finished end)

        demoted_pieces =
          get_first_goal_pieces(game)
          |> Enum.filter(fn {c, _p} -> c != current_team end)
          |> Enum.filter(fn {c, _p} -> !Enum.any?(finished_teams, fn p -> p.color == c end) end)
          |> Enum.map(fn {_c, p} -> p end)

        demoted =
          handle_demoted_pieces(game, demoted_pieces) ++
            Map.get(changes, :animated_effects, [])

        team = game.teams |> Enum.find(fn p -> p.color == current_team end)
        {:ok, _team} = update_team(team, %{can_raise: false})

        Map.put(Map.put(changes, :animated_effects, demoted), :raise, %{team: current_team})
      else
        changes
      end

    {game, finishing_teams} = check_game_end(game |> Repo.preload(:pieces, force: true))

    changes = Map.put(changes, :finishing_teams, finishing_teams)

    game = check_hembo(game, initial_game)

    next_team = get_next_team(game)

    {:ok, game} = update_game(game, %{current_team: next_team, roll: nil, roll_count: 0})

    game = game |> Repo.preload(:pieces, force: true)

    {game, changes}
  end

  def get_game(id) do
    Repo.get(Game, id)
  end

  def get_game_by(attrs) do
    game = Repo.get_by(Game, attrs)

    case game do
      nil -> {:error, "Game not found"}
      game -> {:ok, game}
    end
  end

  def get_team_by(attrs) do
    Repo.get_by(Team, attrs)
  end

  def can_be_started?(%Game{has_started: true}) do
    false
  end

  def can_be_started?(%Game{has_started: false} = game) do
    teams_with_players =
      game.teams
      |> Enum.map(fn team -> {team, length(team.players)} end)
      |> Enum.filter(fn {_t, count} -> count > 0 end)
      |> Enum.map(fn {team, _c} -> team end)

    team_count = length(teams_with_players)

    team_count >= Constants.min_team_count()
  end

  defp preload_game(game, opts \\ []) when is_list(opts) do
    game =
      game
      |> Repo.preload(:pieces, opts)
      |> Repo.preload(:players, opts)
      |> Repo.preload([teams: :players], opts)

    sorted_players = Enum.sort_by(game.players, fn p -> p.inserted_at end, NaiveDateTime)
    sorted_teams = Enum.sort_by(game.teams, fn t -> t.sort_value end)

    %Game{
      game
      | teams: sorted_teams,
        players: sorted_players,
        can_be_started: can_be_started?(game)
    }
  end

  def get_game_by_code(code) do
    case get_game_by(%{code: code}) do
      {:error, message} -> {:error, message}
      {:ok, game} -> {:ok, preload_game(game)}
    end
  end

  def create_game_with_initial_state(name, code) do
    case create_game(%{name: name, code: code, current_team: :none}) do
      {:ok, game} ->
        1..4
        |> Enum.each(fn i -> {:ok, _team} = create_team(game, %{color: :none, sort_value: i}) end)

        {:ok, preload_game(game)}

      resp ->
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

  def create_team(game, attrs) do
    {:ok, _team} =
      %Team{}
      |> Team.changeset(attrs)
      |> Ecto.Changeset.put_assoc(:game, game)
      |> Repo.insert()
  end

  def get_player(id) do
    Repo.get(Player, id)
  end

  def get_team(id) do
    Repo.get(Team, id)
  end

  def update_player(player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
  end

  def update_team(team, attrs) do
    team
    |> Team.changeset(attrs)
    |> Repo.update()
  end

  def set_team_penalty(%Game{} = game, team_id, amount) do
    case update_team(get_team(team_id), %{penalties: amount}) do
      {:ok, _team} ->
        {:ok, check_game_end(game |> Repo.preload(:pieces) |> Repo.preload(:teams, force: true))}

      {:error, error} ->
        {:error, error}
    end
  end

  def apply_penalties(%Game{teams: teams} = game, penalties) do
    penalties
    |> Enum.each(fn p ->
      team = Enum.find(teams, fn t -> t.color == p.team end)
      {:ok, _team} = set_team_penalty(game, team.id, team.penalties + p.amount)
    end)

    Repo.preload(game, :teams, force: true)
  end

  def agree_to_new_raise(%Game{has_started: false}, _team, _new_raising_round) do
    {:error, "Cannot agree to new raise round during setup"}
  end

  def agree_to_new_raise(
        %Game{} = game,
        %Team{can_raise: false} = team,
        new_raising_round
      )
      when is_boolean(new_raising_round) do
    update_team(team, %{new_raising_round: new_raising_round})
    game = Repo.preload(game, :teams, force: true)

    if(Enum.all?(game.teams, fn p -> p.new_raising_round end)) do
      game.teams
      |> Enum.each(fn p -> update_team(p, %{new_raising_round: false, can_raise: true}) end)

      Repo.preload(game, :teams, force: true)
    else
      game
    end
  end

  def agree_to_new_raise(game, _team, _new_raising_round) do
    game
  end

  def call_missed_hembo(%Game{has_started: false}, _color) do
    {:error, "Cannot call missed hembo during setup"}
  end

  def call_missed_hembo(%Game{teams: teams} = game, color) do
    team = Enum.find(teams, fn t -> t.color == color end)

    if team.needs_hembo do
      {:ok, _team} = update_team(team, %{needs_hembo: false, penalties: team.penalties + 1})

      game = Repo.preload(game, :teams, force: true)
      {:ok, game}
    else
      {:error, "The #{color} team does not need to call hembo"}
    end
  end

  def jag_bor_i_hembo(%Game{has_started: false}, _team) do
    {:error, "Cannot call hembo during setup"}
  end

  def jag_bor_i_hembo(%Game{} = game, %Team{color: color} = team) do
    penalties =
      if team.needs_hembo do
        {:ok, _team} = update_team(team, %{needs_hembo: false})
        []
      else
        {:ok, _team} = update_team(team, %{penalties: team.penalties + 1})
        [%{team_color: color, amount: 1}]
      end

    {:ok, Repo.preload(game, :teams, force: true), penalties}
  end

  def join_team(%Game{} = game, %Team{} = team, %Player{} = player) do
    {:ok, _player} = update_player(player, %{team_id: team.id})

    preload_game(game, force: true)
  end

  def leave_team(%Game{} = game, %Player{} = player) do
    {:ok, _player} = update_player(player, %{team_id: nil})

    preload_game(game, force: true)
  end

  defp get_team_default_name(color) do
    "#{String.capitalize(to_string(color))} team"
  end

  def start_game(%Game{has_started: true}) do
    {:error, "Cannot start an ongoing game"}
  end

  # Host only
  def start_game(%Game{has_started: false} = game) do
    game = preload_game(game)

    teams_with_players =
      game.teams
      |> Enum.map(fn team -> {team, length(team.players)} end)
      |> Enum.filter(fn {_t, count} -> count > 0 end)
      |> Enum.map(fn {team, _c} -> team end)

    team_count = length(teams_with_players)

    if team_count >= Constants.min_team_count() do
      random_colors =
        Constants.team_colors()
        |> Enum.map(fn c -> {c, :rand.uniform_real()} end)
        |> Enum.sort_by(fn {_c, rand} -> rand end)
        |> Enum.map(fn {c, _r} -> c end)

      teams =
        0..(team_count - 1)
        |> Enum.map(fn i -> {Enum.at(teams_with_players, i), Enum.at(random_colors, i)} end)
        |> Enum.map(fn {team, color} ->
          {:ok, updated_team} =
            if Map.get(team, :name) == nil do
              update_team(team, %{color: color, name: get_team_default_name(color)})
            else
              update_team(team, %{color: color})
            end

          updated_team
        end)

      teams
      |> Enum.each(fn team ->
        Constants.start_index_list()
        |> Enum.each(fn i ->
          {:ok, _piece} =
            create_piece(game, %{team_color: team.color, position_index: i, area: :home})
        end)
      end)

      random_index = :rand.uniform(team_count) - 1

      {:ok, game} =
        update_game(game, %{has_started: true, current_team: Enum.at(teams, random_index).color})

      {:ok, preload_game(game, force: true)}
    else
      {:error, "Cannot start game with less than #{Constants.min_team_count()} teams"}
    end
  end
end
