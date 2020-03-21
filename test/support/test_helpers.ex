defmodule WebKimble.TestHelpers do
    alias WebKimble.Networking

    def game_fixture(attrs \\ %{}) do
        {:ok, game} = 
            attrs
            |> Enum.into(%{
                name: "Test Game",
                code: "secret"
            })
            |> Networking.create_game()

        game
    end

end