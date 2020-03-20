defmodule WebKimbleWeb.Channels.LobbyChannelTest do
    use WebKimbleWeb.ChannelCase

    test "join replies ok" do

        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        {:ok, _reply, _socket} = subscribe_and_join(socket, "lobby", %{})

    end

    test "create_game replies ok" do
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        {status, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

        ref = push socket, "create_game", %{}


        assert_reply ref, :ok, %{}
    end

end