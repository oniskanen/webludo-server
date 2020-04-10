defmodule WebKimbleWeb.GameChannel do
  use WebKimbleWeb, :channel

  alias WebKimble.Networking
  alias WebKimble.Logic

  def join("games:" <> code, _params, socket) do
    case Networking.get_game_by_code(code) do
      {:error, message} ->
        {:error, message}

      {:ok, game} ->
        actions = Logic.get_moves(game.game_state)
        {:ok, %{game: game, actions: actions}, assign(socket, :code, code)}
    end
  end

  def handle_in("action", %{"token" => token, "type" => "roll"}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)
    {:ok, game} = Networking.get_game_by_code(socket.assigns.code)

    player = Networking.get_player(player_id)
    current_player = game.game_state.current_player

    case current_player == player.color do
      false ->
        {:reply, {:error, %{error: "It is the #{current_player} player's turn"}}, socket}

      true ->
        num = :rand.uniform(6)

        case Logic.set_roll(game.game_state, num) do
          {:ok, game_state} ->
            actions = Logic.get_moves(game_state)
            broadcast!(socket, "roll", %{result: num})
            broadcast!(socket, "game_state_updated", %{game_state: game_state, actions: actions})
            {:reply, :ok, socket}

          {:error, message} ->
            {:reply, {:error, %{error: message}}, socket}
        end
    end
  end

  def handle_in("action", %{"token" => token, "type" => "move", "move" => move}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)
    {:ok, game} = Networking.get_game_by_code(socket.assigns.code)
    player = Networking.get_player(player_id)
    current_player = game.game_state.current_player

    case current_player == player.color do
      false ->
        {:reply, {:error, %{error: "It is the #{current_player} player's turn"}}, socket}

      true ->
        moves = Logic.get_moves(game.game_state)

        case moves do
          [] ->
            {:reply, {:error, %{message: "No moves available"}}, socket}

          moves ->
            validated_move = Enum.find(moves, fn m -> m.piece_id == move["piece_id"] end)

            case validated_move do
              nil ->
                {:reply, {:error, %{message: "Not a valid move"}}, socket}

              m ->
                {state, changes} = Logic.execute_move(game.game_state, m)

                broadcast!(socket, "game_state_updated", %{
                  game_state: state,
                  changes: changes,
                  actions: []
                })

                {:reply, {:ok, %{game_state: state}}, socket}
            end
        end
    end
  end

  def handle_in("join_game", %{"name" => name}, socket) do
    case Networking.join_game(socket.assigns.code, name) do
      {:ok, player, game} ->
        token = WebKimbleWeb.Auth.get_token(player)
        broadcast!(socket, "game_updated", game)

        {:reply, {:ok, %{token: token, color: player.color}}, socket}

      {:error, message} ->
        {:reply, {:error, %{error: message}}, socket}
    end
  end

  def handle_in("game", _params, socket) do
    {:ok, game} = Networking.get_game_by_code(socket.assigns.code)
    {:reply, {:ok, game}, socket}
  end

  def handle_in("game_state", _params, socket) do
    {:ok, game} = Networking.get_game_by_code(socket.assigns.code)
    {:reply, {:ok, game.game_state}, socket}
  end

  def handle_in("set_penalty", %{"amount" => amount, "token" => token}, socket) do
    {:ok, player_id} = WebKimbleWeb.Auth.get_player_id(token)
    {:ok, _player} = Networking.set_player_penalty(player_id, amount)
    {:ok, game} = Networking.get_game_by_code(socket.assigns.code)

    broadcast!(socket, "game_updated", game)
    {:reply, :ok, socket}
  end
end
