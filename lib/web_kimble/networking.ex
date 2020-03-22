defmodule WebKimble.Networking do

    alias WebKimble.Repo
    alias WebKimble.Networking.Player
    alias WebKimble.Networking.Game
    alias WebKimble.Logic

    def get_game_by(attrs) do
        game = Repo.get_by(Game, attrs)

        case game do
            nil -> {:error, "Game not found"}
            game -> {:ok, game}
        end
    end

    defp preload_game(game, opts \\ []) when is_list(opts) do
        game 
        |> Repo.preload([game_state: :pieces], opts)
        |> Repo.preload(:players, opts)
    end


    def get_game_by_code(code) do
        case get_game_by(%{code: code}) do
            {:error, message} -> {:error, message}
            {:ok, game} -> {:ok, preload_game(game)}
        end
    end

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

    def create_player(game, attrs) do
        {:ok, _player} = %Player{}
        |> Player.changeset(attrs)
        |> Ecto.Changeset.put_assoc(:game, game)
        |> Repo.insert()
    end

    def join_game(code, name) do
        {:ok, game} = get_game_by(%{code: code})

        game = Repo.preload(game, :players)
        taken_colors = game.players |> Enum.map(fn(p) -> p.color end)
        available_colors = Logic.available_colors(taken_colors)

        {:ok, player} = create_player(game, %{name: name, color: Enum.random(available_colors)})

        {:ok, player, preload_game(game, [force: true])}
    end
end