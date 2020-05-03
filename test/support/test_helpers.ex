defmodule WebLudo.TestHelpers do
  alias WebLudo.Logic
  alias WebLudo.Repo
  alias WebLudo.Logic.Game

  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        name: "Test Game",
        code: "secret",
        current_team: :red,
        has_started: true
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
          %{color: :red, sort_value: 1},
          %{color: :blue, sort_value: 2},
          %{color: :green, sort_value: 3},
          %{color: :yellow, sort_value: 4}
        ]
      })

    teams =
      teams
      |> Enum.map(fn t ->
        current_sort = Map.get(t, :sort_value, nil)

        if current_sort == nil do
          Map.put(t, :sort_value, 0)
        else
          t
        end
      end)
      |> Enum.map(fn t ->
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
    preload_game(game) |> Repo.preload(players: [:team])
  end

  # NOTE: Doesn't account for duplicates
  def list_contents_equal?(l1, l2) do
    set1 = MapSet.new(l1)
    set2 = MapSet.new(l2)

    set1 == set2
  end

  defp preload_game(game, opts \\ []) when is_list(opts) do
    game =
      game
      |> Repo.preload(:pieces, opts)
      |> Repo.preload(:players, opts)
      |> Repo.preload([teams: :players], opts)

    sorted_players = Enum.sort_by(game.players, fn p -> p.inserted_at end, NaiveDateTime)
    %Game{game | players: sorted_players, can_be_started: Logic.can_be_started?(game)}
  end
end
