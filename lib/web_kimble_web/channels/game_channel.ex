defmodule WebKimbleWeb.GameChannel do
  use WebKimbleWeb, :channel

  alias WebKimble.Logic

  def join("games:" <> code, _params, socket) do
    case Logic.get_game_by_code(code) do
      {:error, message} ->
        {:error, message}

      {:ok, game} ->
        actions = Logic.get_moves(game)
        {:ok, %{game: game, actions: actions}, assign(socket, :code, code)}
    end
  end

  def handle_in("action", %{"token" => token, "type" => "roll"}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)
    {:ok, game} = Logic.get_game_by_code(socket.assigns.code)

    player = Logic.get_player(player_id)
    current_player = game.current_player

    case current_player == player.color do
      false ->
        {:reply, {:error, %{error: "It is the #{current_player} player's turn"}}, socket}

      true ->
        num = :rand.uniform(6)

        case Logic.set_roll(game, num) do
          {:ok, game} ->
            actions = Logic.get_moves(game)
            broadcast!(socket, "roll", %{result: num})
            broadcast!(socket, "game_updated", %{game: game, actions: actions})
            {:reply, :ok, socket}

          {:error, message} ->
            {:reply, {:error, %{error: message}}, socket}
        end
    end
  end

  def handle_in("action", %{"token" => token, "type" => "move", "move" => move}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)
    {:ok, game} = Logic.get_game_by_code(socket.assigns.code)
    player = Logic.get_player(player_id)
    current_player = game.current_player

    case current_player == player.color do
      false ->
        {:reply, {:error, %{error: "It is the #{current_player} player's turn"}}, socket}

      true ->
        moves = Logic.get_moves(game)

        case moves do
          [] ->
            {:reply, {:error, %{message: "No moves available"}}, socket}

          moves ->
            validated_move = Enum.find(moves, fn m -> m.piece_id == move["piece_id"] end)

            case validated_move do
              nil ->
                {:reply, {:error, %{message: "Not a valid move"}}, socket}

              m ->
                {game, changes} = Logic.execute_move(game, m)

                penalties = Map.get(changes, :penalties, [])
                game = Logic.apply_penalties(game, penalties)

                broadcast!(socket, "game_updated", %{game: game, changes: changes, actions: []})

                {:reply, :ok, socket}
            end
        end
    end
  end

  def handle_in("join_game", %{"name" => name}, socket) do
    case Logic.join_game(socket.assigns.code, name) do
      {:ok, player, game} ->
        token = WebKimbleWeb.Auth.get_token(player)
        actions = Logic.get_moves(game)
        broadcast!(socket, "game_updated", %{game: game, actions: actions})

        {:reply, {:ok, %{token: token, color: player.color}}, socket}

      {:error, message} ->
        {:reply, {:error, %{error: message}}, socket}
    end
  end

  def handle_in("game", _params, socket) do
    {:ok, game} = Logic.get_game_by_code(socket.assigns.code)
    {:reply, {:ok, game}, socket}
  end

  def handle_in("set_penalty", %{"amount" => amount, "token" => token}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)

    handle_player_penalty(player_id, amount, socket)
  end

  def handle_in("decrement_penalty", %{"token" => token}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)
    player = Logic.get_player(player_id)

    handle_player_penalty(player_id, player.penalties - 1, socket)
  end

  def handle_in("chat", %{"token" => token, "message" => message}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)
    player = Logic.get_player(player_id)

    broadcast!(socket, "chat", %{message: message, player: player.name})

    {:reply, :ok, socket}
  end

  defp handle_player_penalty(player_id, amount, socket) do
    case Logic.set_player_penalty(player_id, amount) do
      {:ok, _player} ->
        {:ok, game} = Logic.get_game_by_code(socket.assigns.code)
        actions = Logic.get_moves(game)
        broadcast!(socket, "game_updated", %{game: game, actions: actions})
        {:reply, :ok, socket}

      {:error, error} ->
        {:reply, {:error, %{errors: error.errors}}, socket}
    end
  end
end
