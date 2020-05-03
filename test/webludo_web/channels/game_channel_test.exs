defmodule WebLudoWeb.Channels.GameChannelTest do
  use WebLudoWeb.ChannelCase

  alias WebLudo.TestHelpers
  alias WebLudoWeb.Auth

  test "join replies with game" do
    game = TestHelpers.game_fixture()
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})
    assert {:ok, reply, _socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    assert %{game: %{players: _players, pieces: pieces}} = reply
    assert 16 == length(pieces)
  end

  test "join replies with error for nonexistent game" do
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:error, "Game not found"} = subscribe_and_join(socket, "games:invalid", %{})
  end

  test "join game broadcasts game with list of players" do
    game = TestHelpers.game_fixture(%{players: []})
    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    ref = push(socket, "join_game", %{name: "Test Name"})

    assert_reply ref, :ok, %{}
    assert_broadcast "game_updated", %{game: %{players: [%{name: "Test Name"}]}}
  end

  test "join game responds with a player token" do
    game = TestHelpers.game_fixture()

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})
    ref = push(socket, "join_game", %{name: "Player 5"})
    assert_reply ref, :ok, %{token: token}
  end

  test "join game responds with a player id" do
    game = TestHelpers.game_fixture()

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})
    ref = push(socket, "join_game", %{name: "Player 5"})
    assert_reply ref, :ok, %{id: id}
  end

  test "player not in turn cannot roll die" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :blue
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    ref = push(socket, "action", %{token: token, type: "roll"})

    assert_reply ref, :error, %{error: error_message}
    assert "It is the blue team's turn" == error_message
  end

  test "player in turn can roll die" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    ref = push(socket, "action", %{token: token, type: "roll"})

    assert_reply ref, :ok, %{}

    assert_broadcast "roll", %{result: result}

    assert Enum.member?(1..6, result)
  end

  test "move action returns game with pieces in new positions" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        pieces: [%{team_color: :red, area: :home, position_index: 0}],
        roll: 6
      })

    piece = hd(game.pieces)

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    push(socket, "action", %{
      token: token,
      type: "move",
      move: %{piece_id: piece.id, target_area: :play, target_index: 0, type: "move"}
    })

    assert_broadcast "game_updated", %{game: game}

    pieces_in_play = game.pieces |> Enum.filter(fn p -> p.area == :play end)

    assert 1 = length(pieces_in_play)
  end

  test "player rolling twice in a row receives an error" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        pieces: [%{team_color: :red, area: :play, position_index: 0}]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    push(socket, "action", %{token: token, type: "roll"})

    ref = push(socket, "action", %{token: token, type: "roll"})
    assert_reply ref, :error, %{error: error_message}
    assert "Roll needs to be used before rolling again" == error_message
  end

  test "eating a piece causes a game updated message with changes" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        pieces: [%{team_color: :red, area: :play, position_index: 0}]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{changes: changes}

    assert %{move: %{target_area: :play, target_index: 1, start_area: :play, start_index: 0}} =
             changes
  end

  test "eating a piece causes broadcast with eaten piece details" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)
    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{changes: changes}

    assert %{
             animated_effects: [
               %{target_area: :home, target_index: 0, start_area: :play, start_index: 1}
             ]
           } = changes
  end

  test "team data includes penalties" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        teams: [
          %{color: :blue, penalties: 0},
          %{color: :green, penalties: 0},
          %{color: :yellow, penalties: 0}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{game: %{teams: teams}} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    assert [%{penalties: 0}, %{penalties: 0}, %{penalties: 0}] = teams
  end

  test "sending a set penalty message sets the team penalty to provided value" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        teams: [
          %{color: :red, penalties: 0}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    ref = push(socket, "set_penalty", %{token: token, amount: 5})
    assert_reply ref, :ok, %{}

    assert_broadcast "game_updated", %{game: %{teams: teams}}
    assert Enum.any?(teams, &match?(%{color: :red, penalties: 5}, &1))
  end

  test "sending a decrement penalty message reduces the penalty by 1" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        players: [
          %{name: "Player 1"}
        ],
        teams: [
          %{color: :red, penalties: 5},
          %{color: :blue}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})
    assert_broadcast "game_updated", %{game: %{teams: teams}}

    assert Enum.any?(teams, &match?(%{color: :red, penalties: 4}, &1))
  end

  test "sending a decrement penalty message when penalty is a zero keeps penalty at zero" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})
    refute_broadcast "game_updated", %{}

    ref = push(socket, "game", %{token: token})
    assert_reply ref, :ok, %{teams: teams}
    assert Enum.any?(teams, &match?(%{color: :red, penalties: 0}, &1))
  end

  test "eating a piece causes game updated broadcast with penalties" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)
    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{changes: changes}

    assert %{penalties: [%{team: :blue, amount: 1}]} = changes
  end

  test "eating a piece causes game broadcast with updated penalties" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        current_team: :red,
        roll: 1,
        teams: [
          %{color: :red},
          %{color: :blue, penalties: 1},
          %{color: :green},
          %{color: :yellow}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{game: %{teams: teams}}

    assert Enum.any?(teams, &match?(%{color: :blue, penalties: 2}, &1))
  end

  test "sending a new_raising_round message causes game_updated broadcast" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, can_raise: false},
          %{color: :blue},
          %{color: :green},
          %{color: :yellow}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    ref = push(socket, "new_raising_round", %{token: token, agree: true})

    assert_reply ref, :ok, %{}

    assert_broadcast "game_updated", %{game: %{teams: teams}}

    assert teams |> Enum.any?(&match?(%{color: :red, new_raising_round: true}, &1))
  end

  test "sending jag_bor_i_hembo causes a game_updated broadcast" do
    game = WebLudo.TestHelpers.game_fixture()

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    ref = push(socket, "jag_bor_i_hembo", %{token: token})

    assert_reply ref, :ok, %{}

    assert_broadcast "game_updated", %{game: %{teams: teams}}

    assert teams |> Enum.any?(&match?(%{color: :red, penalties: 1}, &1))
  end

  test "sending call_missed_hembo causes a game_updated broadcast when needs_hembo is true for the team" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        teams: [
          %{color: :red},
          %{color: :blue, needs_hembo: true},
          %{color: :green},
          %{color: :yellow}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    ref = push(socket, "call_missed_hembo", %{token: token, team: "blue"})

    assert_reply ref, :ok, %{}

    assert_broadcast "game_updated", %{game: %{teams: teams}}

    blue = Enum.find(teams, &match?(%{color: :blue}, &1))

    assert %{penalties: 1, needs_hembo: false} = blue
  end

  test "sending call_missed_hembo replies with error when needs_hembo is false" do
    game =
      WebLudo.TestHelpers.game_fixture(%{
        teams: [
          %{color: :red},
          %{color: :blue, needs_hembo: false}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))
    token = Auth.get_token(player)

    ref = push(socket, "call_missed_hembo", %{token: token, team: "blue"})

    assert_reply ref, :error, %{message: "The blue team does not need to call hembo"}
  end
end
