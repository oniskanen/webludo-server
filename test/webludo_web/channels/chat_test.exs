defmodule WebLudoWeb.Channels.ChatTest do
  use WebLudoWeb.ChannelCase

  test "sending a chat message causes chat broadcast" do
    game = WebLudo.TestHelpers.game_fixture()

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = WebLudoWeb.Auth.get_token(player)
    ref = push(socket, "chat", %{token: token, message: "Hi chat!"})

    assert_reply ref, :ok, %{}

    assert_broadcast "chat", %{message: "Hi chat!", player: "Player 1"}
  end
end
