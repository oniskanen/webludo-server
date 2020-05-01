defmodule WebLudoWeb.Channels.GameSetupTest do
  use WebLudoWeb.ChannelCase

  test "a player can join a game when is has not started" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{code: code, host_token: _token} = params

    {:ok, %{game: game}, socket} = subscribe_and_join(socket, "games:#{code}", %{})

    ref = push(socket, "join_game", %{name: "Player 1"})
    assert_reply ref, :ok, %{token: token}

    ref = push(socket, "join_team", %{token: token, team_id: hd(game.teams).id})
    assert_reply ref, :ok, %{}
  end

  test "join_team causes a game_updated broadcast" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{code: code, host_token: _token} = params

    {:ok, %{game: game}, socket} = subscribe_and_join(socket, "games:#{code}", %{})

    ref = push(socket, "join_game", %{name: "Player 1"})
    assert_reply ref, :ok, %{token: token}
    assert_broadcast "game_updated", %{}

    team_id = hd(game.teams).id
    push(socket, "join_team", %{token: token, team_id: team_id})

    assert_broadcast "game_updated", %{game: game}

    assert Enum.any?(game.teams, &match?(%{id: ^team_id, players: [%{name: "Player 1"}]}, &1))
  end
end
