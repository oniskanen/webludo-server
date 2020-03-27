defmodule WebKimble.Logic do

    alias WebKimble.Repo
    alias WebKimble.Logic.GameState
    alias WebKimble.Logic.Move
    alias WebKimble.Logic.Constants
    alias WebKimble.Logic.Piece

    def create_initial_game_state(game, attrs) do        
        {:ok, state} = create_game_state(game, attrs)

        initial_pieces = WebKimble.Logic.Constants.initial_pieces()
        
        Enum.each(initial_pieces, fn(p) -> {:ok, _piece} = create_piece(state, p) end)

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
        Constants.player_colors 
        |> Enum.filter(fn(c) -> c not in taken_colors end)
    end

    def set_roll(game_state, roll) do
        update_game_state(game_state, %{roll: roll})
    end

    defp home_to_play_move(%Piece{} = piece) do
        %Move{
            piece_id: piece.id,
            target_area: :play,
            target_index: Constants.get_home_space_index(piece.player_color)
        }
    end

    defp in_play_move(%Piece{} = piece, roll) do
        %Move{
            piece_id: piece.id,
            target_area: :play,
            target_index: piece.position_index + roll
        }
    end

    defp get_piece_move(%Piece{} = piece, roll) do
        case piece.area do
            :home -> if roll == 6 do home_to_play_move(piece) else nil end
            :play -> in_play_move(piece, roll)
            _ -> nil
        end
    end


    def get_moves(game_state) do
        game_state = Repo.preload(game_state, :pieces)

        game_state.pieces
        |> Enum.filter(fn(p) -> p.player_color == game_state.current_player end)
        |> Enum.map(&get_piece_move(&1, game_state.roll))
        |> Enum.filter(fn(m) -> m != nil end)
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
        Enum.random(Constants.player_colors)
    end

    def execute_move(game_state, move) do
        piece = get_piece(move.piece_id)
        {:ok, piece} = update_piece(piece, %{area: move.target_area, position_index: move.target_index})

        game_state = game_state |> Repo.preload(:pieces, [force: true])

        game_state
    end

end