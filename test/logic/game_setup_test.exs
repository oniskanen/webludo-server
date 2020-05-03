# TODO: Move tests that do not deal with teams to game_test
defmodule WebLudo.Logic.GameSetupTest do
  use ExUnit.Case

  alias WebLudo.TestHelpers
  alias WebLudo.Logic.Game
  alias WebLudo.Logic.Player
  alias WebLudo.Logic
  alias WebLudo.Repo

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(WebLudo.Repo)
  end

  test "newly created game contains 4 teams" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{teams: teams} = game
    assert length(teams) == 4
  end

  test "newly created game has not started" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{has_started: false} = game
  end

  test "newly created game can not be started" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{can_be_started: false} = game
  end

  test "game with 4 teams with players can be started" do
    game = TestHelpers.game_fixture(%{has_started: false})

    assert %{can_be_started: true} = game
  end

  test "initial game contains 4 empty teams with a sort value" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{teams: teams, players: players, current_team: :none} = game
    assert length(teams) == 4
    assert players == []
    assert Enum.map(teams, fn t -> t.sort_value end) |> Enum.sort() == [1, 2, 3, 4]
  end

  test "a player can join a team when game has not started" do
    game = TestHelpers.game_fixture(%{has_started: false, players: []})
    team = hd(game.teams)
    {:ok, player} = Logic.create_player(game, %{name: "Player 1"})

    assert %{players: [player]} = Logic.join_team(game, team, player)

    player = Repo.preload(player, :team)

    assert player.team.id == team.id
  end

  test "a player can switch to another team when game has not started" do
    game = TestHelpers.game_fixture(%{has_started: false})

    [team1 | tail] = game.teams
    [team2 | _tail] = tail

    [player] = team1.players

    Logic.join_team(game, team2, player)

    player = Repo.get(Player, player.id) |> Repo.preload(:team)

    assert player.team.id == team2.id
  end

  test "a player can leave a team when game has not started" do
    game = TestHelpers.game_fixture(%{has_started: false})

    [team1 | _tail] = game.teams
    [player] = team1.players

    Logic.leave_team(game, player)

    player = Repo.get(Player, player.id) |> Repo.preload(:team)

    assert player.team == nil
    assert player.team_id == nil
  end

  test "a game can be started" do
    game =
      TestHelpers.game_fixture(%{
        has_started: false
      })

    assert {:ok, game} = Logic.start_game(game)

    assert game.has_started
  end

  # TODO: Relax this to 1 or 2 teams as soon as the game logic supports <4 teams
  test "a game cannot be started with less than 4 teams with players" do
    game =
      TestHelpers.game_fixture(%{
        has_started: false,
        teams: [
          %{color: :red},
          %{color: :blue},
          %{color: :yellow},
          %{color: :green}
        ],
        players: [
          %{name: "Player 1"}
        ]
      })

    assert {:error, "Cannot start game with less than 4 teams"} = Logic.start_game(game)

    game = Repo.get(Game, game.id)
    assert not game.has_started
  end

  test "starting a game assigns colors to playing teams" do
    game =
      TestHelpers.game_fixture(%{
        has_started: false,
        teams: [
          %{color: :none},
          %{color: :none},
          %{color: :none},
          %{color: :none}
        ]
      })

    assert {:ok, game} = Logic.start_game(game)

    assert Enum.any?(game.teams, fn t -> t.color == :red end)
    assert Enum.any?(game.teams, fn t -> t.color == :blue end)
    assert Enum.any?(game.teams, fn t -> t.color == :yellow end)
    assert Enum.any?(game.teams, fn t -> t.color == :green end)
  end

  test "starting a game creates 4 pieces in home for playing teams" do
    game = TestHelpers.game_fixture(%{has_started: false, current_team: :none, pieces: []})

    assert {:ok, %{pieces: pieces}} = Logic.start_game(game)

    assert length(pieces) == 16
    assert Enum.all?(pieces, fn p -> p.area == :home end)
    assert length(Enum.filter(pieces, fn p -> p.team_color == :red end)) == 4
    assert length(Enum.filter(pieces, fn p -> p.team_color == :blue end)) == 4
    assert length(Enum.filter(pieces, fn p -> p.team_color == :yellow end)) == 4
    assert length(Enum.filter(pieces, fn p -> p.team_color == :green end)) == 4
  end

  test "game that has not been started has current_team set to none" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert game.current_team == :none
  end

  test "starting a game sets current_team" do
    game = TestHelpers.game_fixture(%{has_started: false, current_team: :none})

    assert {:ok, %{current_team: current_team}} = Logic.start_game(game)

    assert current_team != :none
  end

  test "starting a game sets default team names to unnamed teams" do
    game =
      TestHelpers.game_fixture(%{
        has_started: false,
        teams: [
          %{color: :red},
          %{color: :blue},
          %{color: :yellow},
          %{color: :green}
        ]
      })

    assert {:ok, %{teams: teams}} = Logic.start_game(game)

    assert Enum.any?(teams, &match?(%{color: :red, name: "Red team"}, &1))
    assert Enum.any?(teams, &match?(%{color: :blue, name: "Blue team"}, &1))
    assert Enum.any?(teams, &match?(%{color: :yellow, name: "Yellow team"}, &1))
    assert Enum.any?(teams, &match?(%{color: :green, name: "Green team"}, &1))
  end

  test "cannot roll during setup" do
    game = TestHelpers.game_fixture(%{has_started: false})

    assert {:error, "Cannot roll during setup"} = Logic.set_roll(game, 6)
  end

  test "no moves are available during setup" do
    game = TestHelpers.game_fixture(%{has_started: false, roll: 6})

    assert [] = Logic.get_moves(game)
  end

  test "hembo cannot be called during setup" do
    game = TestHelpers.game_fixture(%{has_started: false, roll: 6})
    %{teams: teams} = game

    assert {:error, "Cannot call hembo during setup"} = Logic.jag_bor_i_hembo(game, hd(teams))
  end

  test "missed hembo cannot be called during setup" do
    game = TestHelpers.game_fixture(%{has_started: false, roll: 6})

    assert {:error, "Cannot call missed hembo during setup"} = Logic.call_missed_hembo(game, :red)
  end

  test "agree to new raise round cannot be called during setup" do
    game = TestHelpers.game_fixture(%{has_started: false})
    team = hd(game.teams)

    assert {:error, "Cannot agree to new raise round during setup"} =
             Logic.agree_to_new_raise(game, team, true)
  end

  @tag :skip
  test "cannot join a team from another game" do
    # TODO
    assert false
  end
end
