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
      message: "The red player says 'Jag bor i hembo'",
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
      message: "The red player says 'Jag bor i hembo'",
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
      message: "Incorrect hembo! The red player gets a penalty"
    }
  end
end
