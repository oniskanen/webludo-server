defmodule WebLudo.TestHelpers do
  alias WebLudo.Logic
  alias WebLudo.Repo
  alias WebLudo.Logic.Game

  def game_fixture(attrs \\ %{}) do
    get_game_fixture(attrs, true)
  end

  def setup_game_fixture(attrs \\ %{}) do
    get_game_fixture(attrs, false)
  end

  defp get_game_fixture(attrs, start_game) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        name: "Test Game",
        code: "secret",
        current_team: :none,
        has_started: false
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
          %{color: :none, sort_value: 1},
          %{color: :none, sort_value: 2},
          %{color: :none, sort_value: 3},
          %{color: :none, sort_value: 4}
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
    |> Enum.each(fn {player, team} -> {:ok, _game} = Logic.join_team(game, team, player) end)

    game =
      if start_game do
        %{pieces: pieces} =
          attrs
          |> Enum.into(%{
            pieces: WebLudo.Logic.Constants.initial_pieces()
          })

        Enum.each(pieces, fn p -> {:ok, _piece} = Logic.create_piece(game, p) end)

        0..3
        |> Enum.map(fn i -> {i, Enum.at(teams, i)} end)
        |> Enum.filter(fn {_i, team} -> team != nil end)
        # This will potentially assign duplicate colors if the test specifies teams with only some colors assigned
        |> Enum.filter(fn {_i, team} -> team.color == :none or team.color == nil end)
        |> Enum.map(fn {i, t} -> {Enum.at(WebLudo.Logic.Constants.team_colors(), i), t} end)
        |> Enum.each(fn {c, t} -> Logic.update_team(t, %{color: c}) end)

        {:ok, game} = Logic.update_game(game, %{has_started: true})

        game =
          if game.current_team == nil || game.current_team == :none do
            {:ok, game} = Logic.update_game(game, %{current_team: :red})
            game
          else
            game
          end

        game
      else
        game
      end

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
