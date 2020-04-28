defmodule WebLudo.TestHelpers do
  alias WebLudo.Logic
  alias WebLudo.Repo

  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        name: "Test Game",
        code: "secret",
        current_team: :red
      })
      |> Logic.create_game()

    %{players: players} =
      attrs
      |> Enum.into(%{
        players: [
          %{name: "Player 1"},
          %{name: "Player 2"},
          %{name: "Player 3"},
          %{name: "Player 4"}
        ]
      })

    players =
      Enum.map(players, fn p ->
        {:ok, player} = Logic.create_player(game, p)
        player
      end)
      |> Enum.filter(fn p -> p != nil end)

    %{teams: teams} =
      attrs
      |> Enum.into(%{
        teams: [
          %{color: :red},
          %{color: :blue},
          %{color: :green},
          %{color: :yellow}
        ]
      })

    teams =
      Enum.map(teams, fn t ->
        {:ok, team} = Logic.create_team(game, t)
        team
      end)
      |> Enum.filter(fn t -> t != nil end)

    0..3
    |> Enum.map(fn i -> {Enum.at(players, i), Enum.at(teams, i)} end)
    |> Enum.filter(fn {p, t} -> p != nil and t != nil end)
    |> Enum.each(fn {player, team} -> Logic.join_team(game, team, player) end)

    %{pieces: pieces} =
      attrs
      |> Enum.into(%{
        pieces: WebLudo.Logic.Constants.initial_pieces()
      })

    Enum.each(pieces, fn p -> {:ok, _piece} = Logic.create_piece(game, p) end)
    game |> Repo.preload(:teams) |> Repo.preload(players: [:team]) |> Repo.preload(:pieces)
  end

  # NOTE: Doesn't account for duplicates
  def list_contents_equal?(l1, l2) do
    set1 = MapSet.new(l1)
    set2 = MapSet.new(l2)

    set1 == set2
  end
end
