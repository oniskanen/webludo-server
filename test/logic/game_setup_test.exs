# TODO: Move tests that do not deal with teams to game_test
defmodule WebLudo.Logic.GameSetupTest do
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
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{has_started: false} = game
  end

  test "newly created game can not be started" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

    assert %{can_be_started: false} = game
  end

  test "game with 4 teams with players can be started" do
    game = TestHelpers.game_fixture()

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
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    team = hd(game.teams)
    {:ok, _player} = Logic.create_player(game, %{name: "Player 1"})

    assert {:ok, %{players: [player]}} = Logic.get_game_by_code("secret")

    assert %{players: [player]} = Logic.join_team(game, team, player)

    player = Repo.preload(player, :team)

    assert player.team.id == team.id
  end

  test "a player can switch to another team when game has not started" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1 | tail] = game.teams
    [team2 | _tail] = tail

    {:ok, player} = Logic.create_player(game, %{name: "Player 1"})

    %{players: [player]} = Logic.join_team(game, team1, player)
    %{players: [player]} = Logic.join_team(game, team2, player)

    player = Repo.preload(player, :team, force: true)

    assert player.team.id == team2.id
  end

  test "a player can leave a team when game has not started" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1 | _tail] = game.teams

    {:ok, player} = Logic.create_player(game, %{name: "Player 1"})

    %{players: [player]} = Logic.join_team(game, team1, player)
    %{players: [player]} = Logic.leave_team(game, player)

    player = Repo.preload(player, :team, force: true)

    assert player.team == nil
    assert player.team_id == nil
  end

  test "a game can be started" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1, team2, team3, team4] = game.teams

    {:ok, player1} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player2} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player3} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player4} = Logic.create_player(game, %{name: "Player 1"})

    Logic.join_team(game, team1, player1)
    Logic.join_team(game, team2, player2)
    Logic.join_team(game, team3, player3)
    Logic.join_team(game, team4, player4)

    game = Repo.preload(game, [teams: :players], force: true)
    assert {:ok, game} = Logic.start_game(game)

    assert game.has_started
  end

  # TODO: Relax this to 1 or 2 teams as soon as the game logic supports <4 teams
  test "a game cannot be started with less than 4 teams" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1 | _tail] = game.teams

    {:ok, player1} = Logic.create_player(game, %{name: "Player 1"})

    Logic.join_team(game, team1, player1)

    assert {:error, "Cannot start game with less than 4 teams"} = Logic.start_game(game)

    game = Repo.get(Game, game.id)
    assert not game.has_started
  end

  test "starting a game assigns colors to playing teams" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1, team2, team3, team4] = game.teams

    {:ok, player1} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player2} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player3} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player4} = Logic.create_player(game, %{name: "Player 1"})

    Logic.join_team(game, team1, player1)
    Logic.join_team(game, team2, player2)
    Logic.join_team(game, team3, player3)
    Logic.join_team(game, team4, player4)

    game = Repo.preload(game, [teams: :players], force: true)
    assert {:ok, game} = Logic.start_game(game)

    assert Enum.any?(game.teams, fn t -> t.color == :red end)
    assert Enum.any?(game.teams, fn t -> t.color == :blue end)
    assert Enum.any?(game.teams, fn t -> t.color == :yellow end)
    assert Enum.any?(game.teams, fn t -> t.color == :green end)
  end

  test "starting a game creates 4 pieces in home for playing teams" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1, team2, team3, team4] = game.teams

    {:ok, player1} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player2} = Logic.create_player(game, %{name: "Player 2"})
    {:ok, player3} = Logic.create_player(game, %{name: "Player 3"})
    {:ok, player4} = Logic.create_player(game, %{name: "Player 4"})

    Logic.join_team(game, team1, player1)
    Logic.join_team(game, team2, player2)
    Logic.join_team(game, team3, player3)
    Logic.join_team(game, team4, player4)

    game = Repo.preload(game, [teams: :players], force: true)
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
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1, team2, team3, team4] = game.teams

    {:ok, player1} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player2} = Logic.create_player(game, %{name: "Player 2"})
    {:ok, player3} = Logic.create_player(game, %{name: "Player 3"})
    {:ok, player4} = Logic.create_player(game, %{name: "Player 4"})

    Logic.join_team(game, team1, player1)
    Logic.join_team(game, team2, player2)
    Logic.join_team(game, team3, player3)
    Logic.join_team(game, team4, player4)

    game = Repo.preload(game, [teams: :players], force: true)
    assert {:ok, %{current_team: current_team}} = Logic.start_game(game)

    assert current_team != :none
  end

  test "starting a game sets default team names to unnamed teams" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")
    game = Repo.preload(game, :teams)

    [team1, team2, team3, team4] = game.teams

    {:ok, player1} = Logic.create_player(game, %{name: "Player 1"})
    {:ok, player2} = Logic.create_player(game, %{name: "Player 2"})
    {:ok, player3} = Logic.create_player(game, %{name: "Player 3"})
    {:ok, player4} = Logic.create_player(game, %{name: "Player 4"})

    Logic.join_team(game, team1, player1)
    Logic.join_team(game, team2, player2)
    Logic.join_team(game, team3, player3)
    Logic.join_team(game, team4, player4)

    game = Repo.preload(game, [teams: :players], force: true)
    assert {:ok, %{teams: teams}} = Logic.start_game(game)

    assert Enum.any?(teams, &match?(%{color: :red, name: "Red team"}, &1))
    assert Enum.any?(teams, &match?(%{color: :blue, name: "Blue team"}, &1))
    assert Enum.any?(teams, &match?(%{color: :yellow, name: "Yellow team"}, &1))
    assert Enum.any?(teams, &match?(%{color: :green, name: "Green team"}, &1))
  end

  test "cannot roll during setup" do
    {:ok, game} = Logic.create_game_with_initial_state("Test Game", "secret")

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

  @tag :skip
  test "cannot join a team from another game" do
    # TODO
    assert false
  end
end
