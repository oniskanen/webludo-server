defmodule WebKimbleWeb.Channels.GameChannelTest do
    use WebKimbleWeb.ChannelCase

    test "join replies with game and gamestate" do
        game = WebKimble.TestHelpers.game_fixture()
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        assert {:ok, reply, _socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

        assert %{game: %{players: _players}, gamestate: %{}} = reply
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

end