defmodule WebLudoWeb.GameChannel do
  use WebLudoWeb, :channel

  alias WebLudo.Logic
  alias WebLudo.Logic.Constants

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
    {:ok, player_id} = WebLudoWeb.Auth.get_player_id(token)
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
    {:ok, player_id} = WebLudoWeb.Auth.get_player_id(token)
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

                handle_penalty_announcement(penalties, socket)

                finishing_players = Map.get(changes, :finishing_players, [])
                handle_finish_announcement(finishing_players, socket)

                multiplied_piece = Map.get(changes, :doubled, %{})
                handle_multiplied_announcement(multiplied_piece, socket)

                raise_info = Map.get(changes, :raise, %{})
                handle_raise_announcement(raise_info, socket)

                broadcast!(socket, "game_updated", %{game: game, changes: changes, actions: []})

                {:reply, :ok, socket}
            end
        end
    end
  end

  def handle_in("join_game", %{"name" => name}, socket) do
    case Logic.join_game(socket.assigns.code, name) do
      {:ok, player, game} ->
        token = WebLudoWeb.Auth.get_token(player)
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
    {:ok, player_id} = WebLudoWeb.Auth.get_player_id(token)
    %{penalties: previous_penalties, color: color} = Logic.get_player(player_id)

    response = handle_player_penalty(player_id, amount, socket)

    if match?({:reply, :ok, _}, response) do
      announce(
        "The #{String.capitalize(to_string(color))} player fixed their penalty value to #{amount} (used to be #{
          previous_penalties
        }).",
        socket
      )
    end

    response
  end

  def handle_in("decrement_penalty", %{"token" => token}, socket) do
    {:ok, player_id} = WebLudoWeb.Auth.get_player_id(token)
    player = Logic.get_player(player_id)

    response = handle_player_penalty(player_id, player.penalties - 1, socket)

    case player.penalties - 1 do
      0 ->
        announce(
          "#{String.capitalize(to_string(player.color))} player finished a penalty. That's their last one!",
          socket
        )

      new_amount ->
        announce(
          "#{String.capitalize(to_string(player.color))} player finished a penalty. #{new_amount} more to go!",
          socket
        )
    end

    response
  end

  def handle_in("chat", %{"token" => token, "message" => message}, socket) do
    {:ok, player_id} = WebLudoWeb.Auth.get_player_id(token)
    player = Logic.get_player(player_id)

    broadcast!(socket, "chat", %{
      message: message,
      player: player.name,
      timestamp: DateTime.now!("Etc/UTC")
    })

    {:reply, :ok, socket}
  end

  def handle_in(
        "new_raising_round",
        %{"token" => token, "agree" => agree},
        socket
      )
      when is_boolean(agree) do
    {:ok, game} = Logic.get_game_by_code(socket.assigns.code)

    {:ok, player_id} = WebLudoWeb.Auth.get_player_id(token)
    player = Logic.get_player(player_id)

    game = Logic.agree_to_new_raise(game, player, agree)
    moves = Logic.get_moves(game)

    broadcast!(socket, "game_updated", %{game: game, actions: moves})

    {:reply, :ok, socket}
  end

  def handle_in("jag_bor_i_hembo", %{"token" => token}, socket) do
    {:ok, game} = Logic.get_game_by_code(socket.assigns.code)

    {:ok, player_id} = WebLudoWeb.Auth.get_player_id(token)
    player = Logic.get_player(player_id)

    {game, penalties} = Logic.jag_bor_i_hembo(game, player.color)
    moves = Logic.get_moves(game)

    broadcast!(socket, "game_updated", %{game: game, actions: moves})

    announce(
      "The #{String.capitalize(to_string(player.color))} player says \"Jag bor i hembo\".",
      socket
    )

    case penalties do
      [%{amount: 1, player_color: color}] ->
        announce(
          "Incorrect hembo! The #{String.capitalize(to_string(color))} player gets a penalty.",
          socket
        )

      _ ->
        nil
    end

    {:reply, :ok, socket}
  end

  def handle_in("call_missed_hembo", %{"token" => token, "player" => playerColorString}, socket) do
    {:ok, game} = Logic.get_game_by_code(socket.assigns.code)

    {:ok, _player_id} = WebLudoWeb.Auth.get_player_id(token)

    player = game.players |> Enum.find(fn p -> to_string(p.color) == playerColorString end)

    case Logic.call_missed_hembo(game, player.color) do
      {:ok, game} ->
        moves = Logic.get_moves(game)
        broadcast!(socket, "game_updated", %{game: game, actions: moves})

        announce(
          "The #{String.capitalize(to_string(player.color))} player missed calling hembo. Penalty to the #{
            String.capitalize(to_string(player.color))
          } player.",
          socket
        )

        {:reply, :ok, socket}

      {:error, message} ->
        {:reply, {:error, %{message: message}}, socket}
    end
  end

  defp announce(message, socket) do
    broadcast!(socket, "announcement", %{message: message, timestamp: DateTime.now!("Etc/UTC")})
  end

  defp handle_player_penalty(player_id, amount, socket) do
    {:ok, game} = Logic.get_game_by_code(socket.assigns.code)

    case Logic.set_player_penalty(game, player_id, amount) do
      {:ok, {game, finishing_players}} ->
        actions = Logic.get_moves(game)
        broadcast!(socket, "game_updated", %{game: game, actions: actions})
        handle_finish_announcement(finishing_players, socket)
        {:reply, :ok, socket}

      {:error, error} ->
        {:reply, {:error, %{errors: error.errors}}, socket}
    end
  end

  defp handle_penalty_announcement(penalties, socket) do
    case penalties do
      [%{player: color, amount: 1, type: "eat"}] ->
        announce(
          "#{String.capitalize(to_string(color))} player eaten! Penalty to the #{
            String.capitalize(to_string(color))
          } player.",
          socket
        )

      [%{player: color, amount: amount, eaten: eaten, eater: eater, type: "eat"}] ->
        announce(
          "#{String.capitalize(to_string(color))} player #{eaten} eaten by a #{eater}! #{amount} penalties to the #{
            String.capitalize(to_string(color))
          } player.",
          socket
        )

      [%{player: color, amount: 1, type: "mine"}] ->
        announce(
          "#{String.capitalize(to_string(color))} player walks into a mine! Penalty to the #{
            String.capitalize(to_string(color))
          } player.",
          socket
        )

      [%{player: color, amount: amount, eaten: eaten, eater: eater, type: "mine"}] ->
        announce(
          "#{String.capitalize(to_string(color))} player walks a #{eaten} into a #{eater} mine! #{
            amount
          } penalties to the #{String.capitalize(to_string(color))} player.",
          socket
        )

      [] ->
        nil
    end
  end

  defp handle_finish_announcement(finishing_players, socket) do
    case finishing_players do
      [player] ->
        announce("The #{String.capitalize(to_string(player))} player finishes the game!", socket)

      _ ->
        nil
    end
  end

  defp handle_multiplied_announcement(multiplied_piece, socket) do
    case multiplied_piece do
      %{multiplier: multiplier, player: player} when multiplier > 1 ->
        verb = Constants.multiplier_verb(multiplier)
        announce("The #{String.capitalize(to_string(player))} player #{verb} a piece.", socket)

      _ ->
        nil
    end
  end

  defp handle_raise_announcement(raise_info, socket) do
    case raise_info do
      %{player: player} ->
        announce("The #{String.capitalize(to_string(player))} player raises!", socket)

      _ ->
        nil
    end
  end
end
