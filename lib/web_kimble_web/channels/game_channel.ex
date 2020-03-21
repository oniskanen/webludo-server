defmodule WebKimbleWeb.GameChannel do
    use WebKimbleWeb, :channel

    alias WebKimble.Networking

    def join("games:" <> code, _params, socket) do        
        case Networking.get_game_by_code(code) do
            nil -> {:error, "Game not found"}
            game -> {:ok, game, socket}
        end
    end


    def handle_in("roll", _params, socket) do
        num = :rand.uniform(6)

        broadcast! socket, "roll", %{result: num}

        {:reply, {:ok, %{result: num}}, socket}
    end
end