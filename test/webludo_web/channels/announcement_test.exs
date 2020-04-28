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
        teams: [
          %{color: :red, needs_hembo: true}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "jag_bor_i_hembo", %{token: token})

    assert_broadcast "announcement", %{
      message: "The Red team says \"Jag bor i hembo\".",
      timestamp: _ts
    }
  end

  test "incorrect jag_bor_i_hembo announces Jag bor i hembo" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, needs_hembo: false}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "jag_bor_i_hembo", %{token: token})

    assert_broadcast "announcement", %{
      message: "The Red team says \"Jag bor i hembo\".",
      timestamp: _ts
    }
  end

  test "incorrect jag_bor_i_hembo announces a new penalty" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, needs_hembo: false}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "jag_bor_i_hembo", %{token: token})

    assert_broadcast "announcement", %{
      message: "Incorrect hembo! The Red team gets a penalty."
    }
  end

  test "getting eaten announces a penalty" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red},
          %{color: :blue}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1}
        ],
        current_team: :red,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue team piece eaten! Penalty to the Blue team."
    }
  end

  test "eating announcement has penalty amount when penalty is over 1" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red},
          %{color: :blue}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0, multiplier: 2},
          %{team_color: :red, area: :center, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 1, multiplier: 4},
          %{team_color: :blue, area: :center, position_index: 0},
          %{team_color: :blue, area: :center, position_index: 1},
          %{team_color: :blue, area: :center, position_index: 2}
        ],
        current_team: :red,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue team quatro eaten by a double! 8 penalties to the Blue team."
    }
  end

  test "walking into a mine announces a penalty" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red},
          %{color: :blue}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 27}
        ],
        current_team: :blue,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :blue}}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue team walks into a mine! Penalty to the Blue team."
    }
  end

  test "walking into mine announcement has penalty amount when penalty is over 1" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red},
          %{color: :blue}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :blue, area: :play, position_index: 27, multiplier: 3},
          %{team_color: :blue, area: :center, position_index: 0},
          %{team_color: :blue, area: :center, position_index: 1}
        ],
        current_team: :blue,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :blue}}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "Blue team walks a triple into a single mine! 3 penalties to the Blue team."
    }
  end

  test "completing a penalty causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, penalties: 3}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})

    assert_broadcast "announcement", %{
      message: "Red team finished a penalty. 2 more to go!"
    }
  end

  test "completing the last penalty causes a different announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, penalties: 1}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})

    assert_broadcast "announcement", %{
      message: "Red team finished a penalty. That's their last one!"
    }
  end

  test "setting the penalty value causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, penalties: 6}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "set_penalty", %{token: token, amount: 1})

    assert_broadcast "announcement", %{
      message: "The Red team fixed their penalty value to 1 (used to be 6)."
    }
  end

  test "setting the penalty value to an invalid value does not cause an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, penalties: 6}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "set_penalty", %{token: token, amount: -1})

    refute_broadcast "announcement", %{
      message: _message
    }
  end

  test "finishing the game by finising last penalty causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, penalties: 1}
        ],
        pieces: [
          %{team_color: :red, area: :goal, position_index: 0},
          %{team_color: :red, area: :goal, position_index: 1},
          %{team_color: :red, area: :goal, position_index: 2},
          %{team_color: :red, area: :goal, position_index: 3}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "decrement_penalty", %{token: token})

    assert_broadcast "announcement", %{message: "The Red team finishes the game!"}
  end

  test "finishing the game by moving last piece to goal causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, penalties: 0}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 27},
          %{team_color: :red, area: :goal, position_index: 1},
          %{team_color: :red, area: :goal, position_index: 2},
          %{team_color: :red, area: :goal, position_index: 3}
        ],
        current_team: :red,
        roll: 1
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{message: "The Red team finishes the game!"}
  end

  test "doubling a piece causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red}
        ],
        pieces: [
          %{team_color: :red, area: :play, position_index: 0},
          %{team_color: :red, area: :home, position_index: 1}
        ],
        current_team: :red,
        roll: 6
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    move = hd(actions)

    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{message: "The Red team doubles a piece."}
  end

  test "calling a missed hembo causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red, needs_hembo: true}
        ]
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    push(socket, "call_missed_hembo", %{token: token, team: "red"})

    assert_broadcast "announcement", %{
      message: "The Red team missed calling hembo. Penalty to the Red team."
    }
  end

  test "raising causes an announcement" do
    game =
      TestHelpers.game_fixture(%{
        teams: [
          %{color: :red},
          %{color: :blue},
          %{color: :yellow},
          %{color: :green}
        ],
        pieces: [
          %{team_color: :red, area: :goal, position_index: 0},
          %{team_color: :red, area: :play, position_index: 1},
          %{team_color: :red, area: :play, position_index: 2},
          %{team_color: :red, area: :play, position_index: 3},
          %{team_color: :blue, area: :goal, position_index: 0},
          %{team_color: :yellow, area: :goal, position_index: 0},
          %{team_color: :green, area: :goal, position_index: 0}
        ],
        roll: 6,
        current_team: :red
      })

    {:ok, socket} = connect(WebLudoWeb.UserSocket, %{})

    assert {:ok, %{actions: actions} = reply, socket} =
             subscribe_and_join(socket, "games:#{game.code}", %{})

    player = Enum.find(game.players, &match?(%{team: %{color: :red}}, &1))

    token = Auth.get_token(player)

    move = Enum.find(actions, &match?(%{type: "raise"}, &1))
    push(socket, "action", %{token: token, type: "move", move: Map.from_struct(move)})

    assert_broadcast "announcement", %{
      message: "The Red team raises!"
    }
  end
end
