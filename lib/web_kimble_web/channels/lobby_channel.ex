defmodule WebKimbleWeb.LobbyChannel do
    alias WebKimble.Networking

    use WebKimbleWeb, :channel

    def join("lobby", _params, socket) do
        {:ok, socket}
    end

    defp generate_code do
        chars = Enum.to_list(?a..?z) ++ Enum.to_list(?0..?9)
        length = 8
        to_string Enum.take_random(chars, length)
    end

    defp format_errors(errors) do
        errors
        |> Enum.map(fn(e) -> 
            {field, {message, _details}} = e
            %{field: field, message: message}
        end)
    end


    def handle_in("create_game", params, socket) do
        code = generate_code()
        
        case Networking.create_game(%{code: code, name: params["name"]}) do
            {:ok, game} -> {:reply, {:ok, %{code: game.code}}, socket}
            {:error, %Ecto.Changeset{} = changeset} -> {:reply, {:error, %{type: "ValidationError", details: format_errors(changeset.errors)}}, socket}
        end
    end

    def handle_in("throw", params, socket) do
        {:reply, {:error, params}, socket}
    end

    def handle_in{"noreply", params, socket} do
        {:noreply, socket}
    end
end