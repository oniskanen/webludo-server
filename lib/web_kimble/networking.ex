defmodule WebKimble.Networking do

    alias WebKimble.Repo
    alias WebKimble.Networking.Game


    def get_game_by_code(code) do
        Repo.get_by(Game, %{code: code})
    end

    def create_game(attrs) do
        %Game{}
        |> Game.changeset(attrs)
        |> Repo.insert()
    end

    def list_games() do
        Repo.all(Game)
    end
end