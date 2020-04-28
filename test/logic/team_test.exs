defmodule WebLudo.Logic.TeamTest do
  use ExUnit.Case

  alias WebLudo.TestHelpers
  alias WebLudo.Logic.Game
  alias WebLudo.Logic

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "a game contains teams" do
    game = TestHelpers.game_fixture()

    assert %{teams: teams} = game
  end

  # TODO: Move to game_test
  test "newly created game has not started" do
    game = %Game{}

    assert %{has_started: false} = game
  end

  test "initial game contains 4 empty teams" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{teams: teams, players: players, current_team: :none} = game
    assert length(teams) == 4
    assert length(players) == 0
  end
end
