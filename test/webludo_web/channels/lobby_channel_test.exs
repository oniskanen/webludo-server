defmodule WebLudoWeb.Channels.LobbyChannelTest do
  use WebLudoWeb.ChannelCase

  test "join replies ok" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, _socket} = subscribe_and_join(socket, "lobby", %{})
  end

  test "create_game replies ok with game code" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{code: _code} = params
  end

  test "create_game returns an error when no name given" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{})

    assert_reply ref, :error, %{message: "'name' parameter is required to create a game"}
  end
end
