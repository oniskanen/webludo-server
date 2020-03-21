defmodule WebKimbleWeb.LobbyChannel do
    alias WebKimble.Networking

    use WebKimbleWeb, :channel

    def join("lobby", _params, socket) do
        {:ok, socket}
    end

    defp generate_code do
        chars = Enum.to_list(?a..?z) ++ Enum.to_list(?0..?9)
        length = 8
        Enum.take_random(chars, length)
    end

    def handle_in("create_game", params, socket) do
        code = generate_code()
        game = Networking.create_game(%{code: code})
        {:reply, {:ok, %{code: code}}, socket}
    end
end