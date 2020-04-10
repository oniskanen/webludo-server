defmodule WebKimbleWeb.Channels.GameChannelTest do
  use WebKimbleWeb.ChannelCase

  alias WebKimble.TestHelpers

  test "join replies with game" do
    game = TestHelpers.game_fixture()
    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})
    assert {:ok, reply, _socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    assert %{game: %{players: _players, pieces: pieces}} = reply
    assert 16 == length(pieces)
  end

  test "join replies with error for nonexistent game" do
    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:error, "Game not found"} = subscribe_and_join(socket, "games:invalid", %{})
  end

  test "join game broadcasts game with list of players" do
    game = TestHelpers.game_fixture(%{players: []})
    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    ref = push(socket, "join_game", %{name: "Test Name"})

    assert_reply ref, :ok, %{}
    assert_broadcast "game_updated", %{game: %{players: [%{name: "Test Name"}]}}
  end

  test "4 players joining get different colors" do
    game = TestHelpers.game_fixture(%{players: []})
    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    ref = push(socket, "join_game", %{name: "Player 1"})
    assert_reply ref, :ok, %{}

    ref = push(socket, "join_game", %{name: "Player 2"})
    assert_reply ref, :ok, %{}

    ref = push(socket, "join_game", %{name: "Player 3"})
    assert_reply ref, :ok, %{}

    ref = push(socket, "join_game", %{name: "Player 4"})
    assert_reply ref, :ok, %{}

    ref = push(socket, "game", %{})
    assert_reply ref, :ok, payload

    player_names =
      payload.players
      |> Enum.map(fn p -> p.name end)

    assert TestHelpers.list_contents_equal?(
             ["Player 1", "Player 2", "Player 3", "Player 4"],
             player_names
           )

    player_colors =
      payload.players
      |> Enum.map(fn p -> p.color end)

    assert TestHelpers.list_contents_equal?([:red, :blue, :green, :yellow], player_colors)
  end

  test "join game responds with a player token" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})
    ref = push(socket, "join_game", %{name: "Player 1"})
    assert_reply ref, :ok, %{token: token}
  end

  test "5th player trying to join game receives an error" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1"},
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    ref = push(socket, "join_game", %{name: "Player 5"})
    assert_reply ref, :error, %{error: "Game is full"}
  end

  defp roll(player, socket) do
    push(socket, "action", %{token: player.token, type: "roll"})
  end

  test "player not in turn cannot roll die" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :blue,
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")

    assert_reply roll(p1, socket), :error, %{error: error_message}
    assert "It is the blue player's turn" == error_message
  end

  test "player in turn can roll die" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")

    assert_reply roll(p1, socket), :ok, %{}

    assert_broadcast "roll", %{result: result}

    assert Enum.member?(1..6, result)
  end

  defp join_game(socket, name) do
    ref = push(socket, "join_game", %{name: name})
    assert_reply ref, :ok, player
    player
  end

  test "move action returns game with pieces in new positions" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        pieces: [%{player_color: :red, area: :home, position_index: 0}],
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ],
        roll: 6
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")

    assert_broadcast "game_updated", %{game: _game}

    ref = push(socket, "game", %{})

    assert_reply ref, :ok, %{pieces: pieces}

    %{id: id} = hd(pieces)

    push(socket, "action", %{
      token: p1.token,
      type: "move",
      move: %{piece_id: id, target_area: :play, target_index: 0, type: "move"}
    })

    assert_broadcast "game_updated", %{game: game}

    pieces_in_play = game.pieces |> Enum.filter(fn p -> p.area == :play end)

    assert 1 = length(pieces_in_play)
  end

  test "player rolling twice in a row receives an error" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ],
        pieces: [%{player_color: :red, area: :play, position_index: 0}]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")

    assert_reply roll(p1, socket), :ok, %{}
    assert_reply roll(p1, socket), :error, %{error: error_message}
    assert "Roll needs to be used before rolling again" == error_message
  end

  test "eating a piece causes a game updated message with changes" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ],
        pieces: [%{player_color: :red, area: :play, position_index: 0}]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")

    push(socket, "action", %{token: p1.token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{changes: changes}

    assert %{move: %{target_area: :play, target_index: 1, start_area: :play, start_index: 0}} =
             changes
  end

  test "eating a piece causes broadcast with eaten piece details" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")

    push(socket, "action", %{token: p1.token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{changes: changes}

    assert %{
             animated_effects: [
               %{target_area: :home, target_index: 0, start_area: :play, start_index: 1}
             ]
           } = changes
  end

  test "player data includes penalties" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2", penalties: 0},
          %{color: :green, name: "Player 3", penalties: 0},
          %{color: :yellow, name: "Player 4", penalties: 0}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, %{game: %{players: players}} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    assert [%{penalties: 0}, %{penalties: 0}, %{penalties: 0}] = players
  end

  test "new player joining is assigned 0 penalties" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2", penalties: 0},
          %{color: :green, name: "Player 3", penalties: 0},
          %{color: :yellow, name: "Player 4", penalties: 0}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    join_game(socket, "Player 1")

    assert_broadcast "game_updated", %{game: %{players: players}}
    assert Enum.any?(players, &match?(%{color: :red, name: "Player 1", penalties: 0}, &1))
  end

  test "sending a set penalty message sets the player penalty to provided value" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2", penalties: 0},
          %{color: :green, name: "Player 3", penalties: 0},
          %{color: :yellow, name: "Player 4", penalties: 0}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    %{token: token} = join_game(socket, "Player 1")
    assert_broadcast "game_updated", %{game: %{players: _players}}

    ref = push(socket, "set_penalty", %{token: token, amount: 5})
    assert_reply ref, :ok, %{}

    assert_broadcast "game_updated", %{game: %{players: players}}
    assert Enum.any?(players, &match?(%{color: :red, name: "Player 1", penalties: 5}, &1))
  end

  test "sending a decrement penalty message reduces the penalty by 1" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2", penalties: 0},
          %{color: :green, name: "Player 3", penalties: 0},
          %{color: :yellow, name: "Player 4", penalties: 0}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    %{token: token} = join_game(socket, "Player 1")
    assert_broadcast "game_updated", %{game: %{players: _players}}

    push(socket, "set_penalty", %{token: token, amount: 5})
    assert_broadcast "game_updated", %{game: %{players: _players}}

    push(socket, "decrement_penalty", %{token: token})
    assert_broadcast "game_updated", %{game: %{players: players}}

    assert Enum.any?(players, &match?(%{color: :red, name: "Player 1", penalties: 4}, &1))
  end

  test "sending a decrement penalty message when penalty is a zero keeps penalty at zero" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2", penalties: 0},
          %{color: :green, name: "Player 3", penalties: 0},
          %{color: :yellow, name: "Player 4", penalties: 0}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, _reply, socket} = subscribe_and_join(socket, "games:#{game.code}", %{})

    %{token: token} = join_game(socket, "Player 1")
    assert_broadcast "game_updated", %{game: %{players: _players}}

    push(socket, "decrement_penalty", %{token: token})
    refute_broadcast "game_updated", %{game: %{players: _players}}

    ref = push(socket, "game", %{token: token})
    assert_reply ref, :ok, %{players: players}
    assert Enum.any?(players, &match?(%{color: :red, name: "Player 1", penalties: 0}, &1))
  end

  test "eating a piece causes game updated broadcast with penalties" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")

    push(socket, "action", %{token: p1.token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{changes: changes}

    assert %{penalties: [%{player: :blue, amount: 1}]} = changes
  end

  test "eating a piece causes game broadcast with updated penalties" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        current_player: :red,
        roll: 1,
        players: [
          %{color: :blue, name: "Player 2", penalties: 1},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    p1 = join_game(socket, "Player 1")
    assert_broadcast "game_updated", %{}

    push(socket, "action", %{token: p1.token, type: "move", move: Map.from_struct(hd(actions))})

    assert_broadcast "game_updated", %{game: %{players: players}}

    assert Enum.any?(players, &match?(%{color: :blue, penalties: 2}, &1))
  end

  test "sending a chat message causes chat broadcast" do
    game =
      WebKimble.TestHelpers.game_fixture(%{
        players: [
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ]
      })

    {:ok, socket} = connect(WebKimbleWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    %{token: token} = join_game(socket, "Player 1")

    ref = push(socket, "chat", %{token: token, message: "Hi chat!"})

    assert_reply ref, :ok, %{}

    assert_broadcast "chat", %{message: "Hi chat!", player: "Player 1"}
  end
end
