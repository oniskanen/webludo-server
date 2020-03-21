defmodule WebKimbleWeb.GameChannel do
    use WebKimbleWeb, :channel

    alias WebKimble.Networking

    def join("games:" <> code, _params, socket) do
        

        {:ok, %{game: %{code: code, status: "Fun", 
            players: [
                %{color: :red, name: "Purple"},
                %{color: :green, name: "Green"},
                %{color: :yellow, name: "Yellow"},
                %{color: :blue, name: "Blue"}
            ]}, gamestate: %{}}, 
            assign(socket, :code, code)
        }
    end
end