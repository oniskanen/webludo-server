defmodule WebKimble.TestHelpers do
    alias WebKimble.Networking
    alias WebKimble.Logic

    def game_fixture(attrs \\ %{}) do
        {:ok, game} = 
            attrs
            |> Enum.into(%{
                name: "Test Game",
                code: "secret"
            })
            |> Networking.create_game_with_initial_state()

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