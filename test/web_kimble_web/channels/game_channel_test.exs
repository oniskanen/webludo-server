defmodule WebKimbleWeb.Channels.GameChannelTest do
    use WebKimbleWeb.ChannelCase

    test "join replies with game and gamestate" do

        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        assert {:ok, reply, _socket} = subscribe_and_join(socket, "games:1", %{})

        assert %{game: %{players: _players}, gamestate: %{}} = reply
    end

end