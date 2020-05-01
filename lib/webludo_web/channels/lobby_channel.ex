defmodule WebLudoWeb.LobbyChannel do
  alias WebLudo.Logic
  alias WebLudoWeb.HostAuth

  use WebLudoWeb, :channel

  def join("lobby", _params, socket) do
    {:ok, socket}
  end

  defp generate_code do
    chars = Enum.to_list(?a..?z) ++ Enum.to_list(?0..?9)
    length = 8
    to_string(Enum.take_random(chars, length))
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn e ->
      {field, {message, _details}} = e
      %{field: field, message: message}
    end)
  end

  def handle_in("create_game", %{"name" => name}, socket) do
    code = generate_code()

    case Logic.create_game_with_initial_state(code, name) do
      {:ok, game} ->
        host_token = HostAuth.get_token(game)
        {:reply, {:ok, %{code: game.code, host_token: host_token}}, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:reply, {:error, %{type: "ValidationError", details: format_errors(changeset.errors)}},
         socket}
    end
  end

  def handle_in("create_game", _params, socket) do
    {:reply, {:error, %{message: "'name' parameter is required to create a game"}}, socket}
  end
end
