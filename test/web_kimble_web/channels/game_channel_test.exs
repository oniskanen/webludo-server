defmodule WebKimbleWeb.Channels.GameChannelTest do
    use WebKimbleWeb.ChannelCase

    alias WebKimble.Logic.GameState

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

    test "dice roll replies with number" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        ref = push socket, "roll", %{}

        assert_reply ref, :ok, %{result: result}
        assert Enum.member?(1..6, result)
    end

    test "join game broadcasts game state" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

        assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        ref = push socket, "join_game", %{name: "Test Name"}

        assert_reply ref, :ok, %{}        
    end

end