defmodule WebKimbleWeb.LobbyChannel do
    use WebKimbleWeb, :channel

    def join("lobby", _params, socket) do
        {:ok, socket}
    end

    def handle_in("create_game", params, socket) do
        {:reply, :ok, socket}
    end
end