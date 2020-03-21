defmodule WebKimbleWeb.Channels.LobbyChannelTest do
    use WebKimbleWeb.ChannelCase

    test "join replies ok" do

        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        {:ok, _reply, _socket} = subscribe_and_join(socket, "lobby", %{})

    end

    test "create_game replies ok with game code" do
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

        ref = push socket, "create_game", %{name: "game name"}

        assert_reply ref, :ok, %{code: _code} = params
    end

    test "create_game returns an error when no name given" do
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

        ref = push socket, "create_game", %{}

        assert_reply ref, :error, %{details: [%{field: :name, message: "can't be blank"}], type: "ValidationError"} = params
        
    end

    test "throw returns error with payload" do
        {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
        {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

        ref = push socket, "throw", %{myparams: "some content"}
        
        assert_reply ref, :error, %{"myparams" => "some content"}
    end

end