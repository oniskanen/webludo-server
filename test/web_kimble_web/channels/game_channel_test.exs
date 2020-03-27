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
        game = WebKimble.TestHelpers.game_fixture(%{players: []})
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
        game = WebKimble.TestHelpers.game_fixture(%{players: []})
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
        game = WebKimble.TestHelpers.game_fixture(%{players: [%{color: :red, name: "Player 1"}, %{color: :blue, name: "Player 2"}, %{color: :green, name: "Player 3"}, %{color: :yellow, name: "Player 4"}]})
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        ref = push socket, "join_game", %{name: "Player 5"}
        assert_reply ref, :error, %{error: "Game is full"}
    end

    defp roll(player, socket) do
        push socket, "action", %{token: player.token, type: "roll"}
    end

    test "player not in turn cannot roll die" do
        game = WebKimble.TestHelpers.game_fixture(%{current_player: :blue, players: [%{color: :blue, name: "Player 2"}, %{color: :green, name: "Player 3"}, %{color: :yellow, name: "Player 4"}]})
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        game = Repo.preload(game, :game_state)

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        p1 = join_game(socket, "Player 1")

        assert_reply roll(p1, socket), :error, %{error: error_message}
        assert "It is the blue player's turn" == error_message 

    end

    test "player in turn can roll die" do
        game = WebKimble.TestHelpers.game_fixture(%{current_player: :red, players: [%{color: :blue, name: "Player 2"}, %{color: :green, name: "Player 3"}, %{color: :yellow, name: "Player 4"}]})
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        game = Repo.preload(game, :game_state)

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        p1 = join_game(socket, "Player 1")

        assert_reply roll(p1, socket), :ok, %{result: result}
        assert Enum.member?(1..6, result)
    end

    defp join_game(socket, name) do
        ref = push socket, "join_game", %{name: name}
        assert_reply ref, :ok, player        
        player
    end

    test "move action returns new game state" do
        game = WebKimble.TestHelpers.game_fixture(
            %{current_player: :red,
             pieces: [%{player_color: :red, area: :home, position_index: 0}],
             players: [%{color: :blue, name: "Player 2"}, %{color: :green, name: "Player 3"}, %{color: :yellow, name: "Player 4"}],
             roll: 6
             })
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        p1 = join_game(socket, "Player 1")

        ref = push socket, "action", %{token: p1.token, type: "move",
            move: %{current: %{color: :red, area: :home, position_index: 0}, target: %{color: :red, area: :play, position_index: 0}}}

        assert_reply ref, :ok, %{game_state: game_state}

        pieces_in_play = game_state.pieces |> Enum.filter(fn (p) -> p.area == :play end)

        assert 1 = length pieces_in_play
    end
end