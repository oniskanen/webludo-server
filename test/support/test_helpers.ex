defmodule WebKimble.TestHelpers do
    alias WebKimble.Networking
    alias WebKimble.Logic

    def game_fixture(attrs \\ %{}) do

        {:ok, game} = attrs
        |> Enum.into(%{
            name: "Test Game",
            code: "secret"
        })
        |> Networking.create_game()
    
        %{players: players} = attrs
        |> Enum.into(%{
            players: [%{color: :blue, name: "Player 2"}, %{color: :green, name: "Player 3"}, %{color: :yellow, name: "Player 4"}]
        })

        Enum.each(players, fn(p) -> {:ok, _player} = Networking.create_player(game, p) end)

        gs_attrs = 
            attrs
            |> Enum.into(%{
                current_player: :red
            })
        
        {:ok, game_state} = Logic.create_game_state(game, gs_attrs)


        %{pieces: pieces} = attrs
        |> Enum.into(%{
            pieces: WebKimble.Logic.Constants.initial_pieces()
        })

        Enum.each(pieces, fn(p) -> {:ok, _piece} = Logic.create_piece(game_state, p) end)
        game
    end

    def game_state_fixture(attrs \\ %{}) do
        {:ok, state} =
            attrs
            |> Enum.into(%{
                current_player: :red
            })
            |> Logic.create_game_state()


        %{pieces: pieces} = attrs
        |> Enum.into(%{
            pieces: WebKimble.Logic.Constants.initial_pieces()
        })

        Enum.each(pieces, fn(p) -> {:ok, _piece} = Logic.create_piece(state, p) end)



        state
    end

end