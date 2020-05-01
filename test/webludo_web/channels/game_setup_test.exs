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

  test "host sending start_game message before 4 teams are created gets error reply" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{code: code, host_token: host_token} = params

    {:ok, %{game: _game}, socket} = subscribe_and_join(socket, "games:#{code}", %{})

    ref = push(socket, "start_game", %{host_token: host_token})
    assert_reply ref, :error, %{message: "Cannot start game with less than 4 teams"}
  end

  test "host sending start_game message after 4 teams are created gets ok reply" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{code: code, host_token: host_token} = params

    {:ok, %{game: game}, socket} = subscribe_and_join(socket, "games:#{code}", %{})

    ref = push(socket, "join_game", %{name: "Player 1"})
    assert_reply ref, :ok, %{token: token1}

    ref = push(socket, "join_game", %{name: "Player 2"})
    assert_reply ref, :ok, %{token: token2}

    ref = push(socket, "join_game", %{name: "Player 3"})
    assert_reply ref, :ok, %{token: token3}

    ref = push(socket, "join_game", %{name: "Player 4"})
    assert_reply ref, :ok, %{token: token4}

    [team1, team2, team3, team4] = game.teams

    push(socket, "join_team", %{token: token1, team_id: team1.id})
    push(socket, "join_team", %{token: token2, team_id: team2.id})
    push(socket, "join_team", %{token: token3, team_id: team3.id})
    push(socket, "join_team", %{token: token4, team_id: team4.id})

    ref = push(socket, "start_game", %{host_token: host_token})
    assert_reply ref, :ok, %{}
  end

  test "host sending start_game message after 4 teams are created sends game_updated broadcast" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    {:ok, _reply, socket} = subscribe_and_join(socket, "lobby", %{})

    ref = push(socket, "create_game", %{name: "game name"})

    assert_reply ref, :ok, %{code: code, host_token: host_token} = params

    {:ok, %{game: game}, socket} = subscribe_and_join(socket, "games:#{code}", %{})

    ref = push(socket, "join_game", %{name: "Player 1"})
    assert_reply ref, :ok, %{token: token1}
    assert_broadcast "game_updated", %{}

    ref = push(socket, "join_game", %{name: "Player 2"})
    assert_reply ref, :ok, %{token: token2}
    assert_broadcast "game_updated", %{}

    ref = push(socket, "join_game", %{name: "Player 3"})
    assert_reply ref, :ok, %{token: token3}
    assert_broadcast "game_updated", %{}

    ref = push(socket, "join_game", %{name: "Player 4"})
    assert_reply ref, :ok, %{token: token4}
    assert_broadcast "game_updated", %{}

    [team1, team2, team3, team4] = game.teams

    push(socket, "join_team", %{token: token1, team_id: team1.id})
    assert_broadcast "game_updated", %{}
    push(socket, "join_team", %{token: token2, team_id: team2.id})
    assert_broadcast "game_updated", %{}
    push(socket, "join_team", %{token: token3, team_id: team3.id})
    assert_broadcast "game_updated", %{}
    push(socket, "join_team", %{token: token4, team_id: team4.id})
    assert_broadcast "game_updated", %{}

    push(socket, "start_game", %{host_token: host_token})
    assert_broadcast "game_updated", %{game: game}

    assert game.has_started
  end
end
