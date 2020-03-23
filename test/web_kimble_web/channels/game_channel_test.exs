defmodule WebKimbleWeb.Channels.GameChannelTest do
    use WebKimbleWeb.ChannelCase

    alias WebKimble.Logic.GameState
    alias WebKimble.Repo

    test "join replies with game and gamestate" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        assert {:ok, reply, _socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        assert %{players: _players, game_state: %GameState{} = state} = reply

        assert %{pieces: pieces} = state

        assert 16 == length pieces
    end

    test "join replies with error for nonexistent game" do
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:error, "Game not found"} = subscribe_and_join(socket, "games:invalid", %{})        
    end

    test "join game broadcasts game state" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        ref = push socket, "join_game", %{name: "Test Name"}

        assert_reply ref, :ok, %{}   
        assert_broadcast "game_updated", %{players: [%{name: "Test Name"}]}        
    end

    defp assert_list_contents(l1, l2) do
        set1 = MapSet.new(l1)
        set2 = MapSet.new(l2)
        
        assert set1 == set2
    end

    test "4 players joining get different colors" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        ref = push socket, "join_game", %{name: "Player 1"}
        assert_reply ref, :ok, %{}   

        ref = push socket, "join_game", %{name: "Player 2"}
        assert_reply ref, :ok, %{}   

        ref = push socket, "join_game", %{name: "Player 3"}
        assert_reply ref, :ok, %{}   

        ref = push socket, "join_game", %{name: "Player 4"}
        assert_reply ref, :ok, %{}            

        ref = push socket, "game", %{}
        assert_reply ref, :ok, payload

        player_names = payload.players
            |> Enum.map(fn(p) -> p.name end)

        assert_list_contents(["Player 1", "Player 2", "Player 3", "Player 4"], player_names)

        player_colors = payload.players
            |> Enum.map(fn(p) -> p.color end)

        assert_list_contents([:red, :blue, :green, :yellow], player_colors)        
    end

    test "join game responds with a player token" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})
        ref = push socket, "join_game", %{name: "Player 1"}
        assert_reply ref, :ok, %{token: token}   
    end

    test "5th player trying to join game receives an error" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        ref = push socket, "join_game", %{name: "Player 1"}
        assert_reply ref, :ok, %{}   

        ref = push socket, "join_game", %{name: "Player 2"}
        assert_reply ref, :ok, %{}   

        ref = push socket, "join_game", %{name: "Player 3"}
        assert_reply ref, :ok, %{}   

        ref = push socket, "join_game", %{name: "Player 4"}
        assert_reply ref, :ok, %{}   

        ref = push socket, "join_game", %{name: "Player 5"}
        assert_reply ref, :error, %{error: "Game is full"}
    end

    defp roll(player, socket) do
        push socket, "action", %{token: player.token, type: "roll"}
    end

    test "player not in turn cannot roll die" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        game = Repo.preload(game, :game_state)
        current_player = game.game_state.current_player

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        p1 = join_game(socket, "Player 1")
        p2 = join_game(socket, "Player 2")
        p3 = join_game(socket, "Player 3")
        p4 = join_game(socket, "Player 4")
        
        current = [p1, p2, p3, p4] |> Enum.find(fn(p) -> p.color == current_player end)

        others = [p1, p2, p3, p4] |> Enum.filter(fn(p) -> p.color != current_player end)

        expected_error = "It is the #{current_player} player's turn"
        others 
        |> Enum.each(fn(p) -> 
            assert_reply roll(p, socket), :error, %{error: error_message}
            assert expected_error == error_message 
        end)

        assert_reply roll(current, socket), :ok, %{result: result}
        assert Enum.member?(1..6, result)
    end

    defp join_game(socket, name) do
        ref = push socket, "join_game", %{name: name}
        assert_reply ref, :ok, player        
        player
    end

    test "move action returns new game state" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        game = Repo.preload(game, :game_state)
        current_player = game.game_state.current_player

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        p1 = join_game(socket, "Player 1")
        p2 = join_game(socket, "Player 2")
        p3 = join_game(socket, "Player 3")
        p4 = join_game(socket, "Player 4")

        current = [p1, p2, p3, p4] |> Enum.find(fn(p) -> p.color == current_player end)

        ref = push socket, "action", %{token: current.token, type: "move", move: %{}}

        assert_reply ref, :ok, %{game_state: _game_state}
    end
end