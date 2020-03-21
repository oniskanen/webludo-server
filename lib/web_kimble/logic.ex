defmodule WebKimble.Logic do

    alias WebKimble.Repo
    alias WebKimble.Logic.GameState
    alias WebKimble.Logic.Move
    alias WebKimble.Logic.Constants
    alias WebKimble.Logic.Piece

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

    def get_moves(roll, game_state) do
        game_state = Repo.preload(game_state, :pieces)

        game_state.pieces
        |> Enum.filter(fn(p) -> p.player_color == game_state.current_player end)
        |> Enum.map(fn(p) -> 
            %Move{player_color: p.player_color, 
            current_area: p.area, 
            current_index: p.position_index, 
            target_area: :play, 
            target_index: Constants.get_home_space_index(p.player_color)} 
        end)
        |> Enum.filter(fn(_m) -> roll == 6 end)
    end

    def create_piece(%GameState{} = game_state, attrs) do
        %Piece{}
        |> Piece.changeset(attrs)
        |> Ecto.Changeset.put_assoc(:game_state, game_state)
        |> Repo.insert()

    end

    def random_player() do
        Enum.random(Constants.player_colors)
    end

end