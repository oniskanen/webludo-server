defmodule WebKimbleWeb.Channels.UserSocketTest do
    use WebKimbleWeb.ChannelCase, async: true
    alias WebKimbleWeb.UserSocket

    test "socket anonymous connection" do
        assert {:ok, socket} = connect(UserSocket, %{})
    end

    test "socket authentication with invalid token" do
        assert :error = connect(UserSocket, %{"token" => "123"})
    end

end