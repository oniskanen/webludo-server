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

    assert_reply ref, :ok, %{code: code} = params
    assert String.length(code) == 8
  end

  test "create_game reply includes game name" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{name: "game name"} = params
  end

  test "create_game returns an error when no name given" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{})

    assert_reply ref, :error, %{message: "'name' parameter is required to create a game"}
  end

  test "create game replies with a host token" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{host_token: _token} = params
  end
end
