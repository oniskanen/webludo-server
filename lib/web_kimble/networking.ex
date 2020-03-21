defmodule WebKimble.Networking do

    alias WebKimble.Repo
    alias WebKimble.Networking.Game


    def get_game_by_code(code) do
        Repo.get_by(Game, %{code: code})
        |> Repo.preload(game_state: :pieces)
        |> Repo.preload(:players)
    end

    def create_game(attrs) do
        %Game{}
        |> Game.changeset(attrs)
        |> Repo.insert()        
    end

    def create_game_with_initial_state(attrs) do
        case create_game(attrs) do
            {:ok, game} ->
                initial_player = WebKimble.Logic.random_player()
                {:ok, _state} = WebKimble.Logic.create_game_state(game, %{current_player: initial_player})
                {:ok, game}
            resp -> resp
        end
        
    end

    def list_games() do
        Repo.all(Game)
    end
end