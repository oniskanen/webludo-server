defmodule WebKimbleWeb.GameChannel do
    use WebKimbleWeb, :channel

    alias WebKimble.Networking

    def join("games:" <> code, _params, socket) do
        case Networking.get_game_by_code(code) do
            {:error, message} -> {:error, message}
            {:ok, game} -> {:ok, game, assign(socket, :code, code)}
        end
    end

    def handle_in("roll", _params, socket) do
        num = :rand.uniform(6)

        broadcast! socket, "roll", %{result: num}

        {:reply, {:ok, %{result: num}}, socket}
    end

    def handle_in("join_game", %{"name" => name} = params, socket) do                
        case Networking.join_game(socket.assigns.code, name) do
            {:ok, player, game} ->
                token = WebKimbleWeb.Auth.get_token(player)
                broadcast! socket, "game_updated", game
                {:reply, {:ok, %{token: token, color: player.color}}, socket}
            {:error, message} -> {:reply, {:error, %{error: message}}, socket}
        end

    end

    def handle_in("game", _params, socket) do
       {:ok, game} = Networking.get_game_by_code(socket.assigns.code)
       {:reply, {:ok, game}, socket} 
    end
end