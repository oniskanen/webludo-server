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

  def set_roll(
        %GameState{roll: previous_roll, current_player: current_player, roll_count: roll_count} =
          game_state,
        roll
      )
      when previous_roll == 0 or previous_roll == nil do
    if has_movable_pieces_with_roll?(game_state, roll) do
      update_game_state(game_state, %{roll: roll, roll_count: roll_count + 1})
    else
      if roll_count + 1 < Constants.max_rolls() do
        update_game_state(game_state, %{
          roll: nil,
          current_player: current_player,
          roll_count: roll_count + 1
        })
      else
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

  def get_moves(%GameState{roll: roll, current_player: current_player} = game_state)
      when roll in 1..6 do
    game_state = Repo.preload(game_state, :pieces)

    current_player_pieces =
      game_state.pieces
      |> Enum.filter(fn p -> p.player_color == current_player end)

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

  def execute_move(game_state, move) do
    piece = get_piece(move.piece_id)

    {:ok, _piece} =
      update_piece(piece, %{area: move.target_area, position_index: move.target_index})

    next_player = get_next_player(game_state)
    {:ok, game_state} = update_game_state(game_state, %{current_player: next_player, roll: nil})

    game_state = game_state |> Repo.preload(:pieces, force: true)

    {game_state,
     %{
       piece_id: move.piece_id,
       target_area: move.target_area,
       target_index: move.target_index,
       start_area: piece.area,
       start_index: piece.position_index
     }}
  end
end
