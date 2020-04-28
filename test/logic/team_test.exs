# TODO: Move tests that do not deal with teams to game_test
defmodule WebLudo.Logic.TeamTest do
  use ExUnit.Case

  alias WebLudo.TestHelpers
  alias WebLudo.Logic.Game
  alias WebLudo.Logic
  alias WebLudo.Repo

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "a game contains teams" do
    game = TestHelpers.game_fixture()

    assert %{teams: teams} = game
  end

  test "newly created game has not started" do
    game = %Game{}

    assert %{has_started: false} = game
  end

  test "initial game contains 4 empty teams" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{teams: teams, players: players, current_team: :none} = game
    assert length(teams) == 4
    assert players == []
  end

  test "a player can join a team when game has not started" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    team = hd(game.teams)
    {:ok, _player} = Logic.create_player(game, %{name: "Player 1"})

    assert {:ok, %{players: [player]}} = Logic.get_game_by_code("secret")

    assert %{players: [player]} = Logic.join_team(game, team, player)

    player = Repo.preload(player, :team)

    assert player.team.id == team.id
  end
end
