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

  @tag :skip
  test "cannot join a team from another game" do
    # TODO
    assert false
  end
end
