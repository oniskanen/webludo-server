defmodule WebLudo.Logic.TeamTest do
  use ExUnit.Case

  alias WebLudo.TestHelpers
  alias WebLudo.Logic.Game

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
end
