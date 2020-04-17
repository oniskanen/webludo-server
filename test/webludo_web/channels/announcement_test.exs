defmodule WebLudoWeb.Channels.AnnouncementTest do
  @moduledoc """
  Tests that the different game channel events broadcast announcements
  """
  use WebLudoWeb.ChannelCase

  alias WebLudo.TestHelpers
  alias WebLudoWeb.Auth

  test "correct jag_bor_i_hembo announces Jag bor i hembo" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", needs_hembo: true}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "jag_bor_i_hembo", %{token: token})

    assert_broadcast "announcement", %{
      message: "The Red player says \"Jag bor i hembo\".",
      timestamp: _ts
    }
  end

  test "incorrect jag_bor_i_hembo announces Jag bor i hembo" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", needs_hembo: false}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "jag_bor_i_hembo", %{token: token})

    assert_broadcast "announcement", %{
      message: "The Red player says \"Jag bor i hembo\".",
      timestamp: _ts
    }
  end

  test "incorrect jag_bor_i_hembo announces a new penalty" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", needs_hembo: false}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "jag_bor_i_hembo", %{token: token})

    assert_broadcast "announcement", %{
      message: "Incorrect hembo! The Red player gets a penalty."
    }
  end

  test "getting eaten announces a penalty" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1"},
          %{color: :blue, name: "Player 2"}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1}
        ],
        current_player: :red,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue player eaten! Penalty to the Blue player."
    }
  end

  test "eating announcement has penalty amount when penalty is over 1" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1"},
          %{color: :blue, name: "Player 2"}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0, multiplier: 2},
          %{player_color: :red, area: :center, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 1, multiplier: 4},
          %{player_color: :blue, area: :center, position_index: 0},
          %{player_color: :blue, area: :center, position_index: 1},
          %{player_color: :blue, area: :center, position_index: 2}
        ],
        current_player: :red,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue player quatro eaten by a double! 8 penalties to the Blue player."
    }
  end

  test "walking into a mine announces a penalty" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1"},
          %{color: :blue, name: "Player 2"}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 27}
        ],
        current_player: :blue,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :blue}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue player walks into a mine! Penalty to the Blue player."
    }
  end

  test "walking into mine announcement has penalty amount when penalty is over 1" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1"},
          %{color: :blue, name: "Player 2"}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :blue, area: :play, position_index: 27, multiplier: 3},
          %{player_color: :blue, area: :center, position_index: 0},
          %{player_color: :blue, area: :center, position_index: 1}
        ],
        current_player: :blue,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :blue}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue player walks a triple into a single mine! 3 penalties to the Blue player."
    }
  end

  test "completing a penalty causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", penalties: 3}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})

    assert_broadcast "announcement", %{
      message: "Red player finished a penalty. 2 more to go!"
    }
  end

  test "completing the last penalty causes a different announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", penalties: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})

    assert_broadcast "announcement", %{
      message: "Red player finished a penalty. That's their last one!"
    }
  end

  test "setting the penalty value causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", penalties: 6}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "set_penalty", %{token: token, amount: 1})

    assert_broadcast "announcement", %{
      message: "The Red player fixed their penalty value to 1 (used to be 6)."
    }
  end

  test "setting the penalty value to an invalid value does not cause an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", penalties: 6}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "set_penalty", %{token: token, amount: -1})

    refute_broadcast "announcement", %{
      message: _message
    }
  end

  test "finishing the game by finising last penalty causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", penalties: 1}
        ],
        pieces: [
          %{player_color: :red, area: :goal, position_index: 0},
          %{player_color: :red, area: :goal, position_index: 1},
          %{player_color: :red, area: :goal, position_index: 2},
          %{player_color: :red, area: :goal, position_index: 3}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})

    assert_broadcast "announcement", %{message: "The Red player finishes the game!"}
  end

  test "finishing the game by moving last piece to goal causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", penalties: 0}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 27},
          %{player_color: :red, area: :goal, position_index: 1},
          %{player_color: :red, area: :goal, position_index: 2},
          %{player_color: :red, area: :goal, position_index: 3}
        ],
        current_player: :red,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{message: "The Red player finishes the game!"}
  end

  test "doubling a piece causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", penalties: 0}
        ],
        pieces: [
          %{player_color: :red, area: :play, position_index: 0},
          %{player_color: :red, area: :home, position_index: 1}
        ],
        current_player: :red,
        roll: 6
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{message: "The Red player doubles a piece."}
  end

  test "calling a missed hembo causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1", needs_hembo: true}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    push(socket, "call_missed_hembo", %{token: token, player: "red"})

    assert_broadcast "announcement", %{
      message: "The Red player missed calling hembo. Penalty to the Red player."
    }
  end

  test "raising causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        players: [
          %{color: :red, name: "Player 1"},
          %{color: :blue, name: "Player 2"},
          %{color: :yellow, name: "Player 3"},
          %{color: :green, name: "Player 4"}
        ],
        pieces: [
          %{player_color: :red, area: :goal, position_index: 0},
          %{player_color: :red, area: :play, position_index: 1},
          %{player_color: :red, area: :play, position_index: 2},
          %{player_color: :red, area: :play, position_index: 3},
          %{player_color: :blue, area: :goal, position_index: 0},
          %{player_color: :yellow, area: :goal, position_index: 0},
          %{player_color: :green, area: :goal, position_index: 0}
        ],
        roll: 6,
        current_player: :red
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{color: :red}, &1))

    token = Auth.get_token(player)

    move = Enum.find(actions, &match?(%{type: "raise"}, &1))
    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "The Red player raises!"
    }
  end
end
