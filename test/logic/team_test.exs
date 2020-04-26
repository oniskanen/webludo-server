defmodule WebLudo.Logic.TeamTest do
  use ExUnit.Case

  alias WebLudo.TestHelpers

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "a game contains teams" do
    game = TestHelpers.game_fixture()

    assert %{teams: teams} = game
  end
end
