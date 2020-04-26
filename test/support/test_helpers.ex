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
          %{color: :red, name: "Player 1"},
          %{color: :blue, name: "Player 2"},
          %{color: :green, name: "Player 3"},
          %{color: :yellow, name: "Player 4"}
        ]
      })

    Enum.each(players, fn p -> {:ok, _player} = Logic.create_player(game, p) end)

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

    Enum.each(teams, fn t -> {:ok, _team} = Logic.create_team(game, t) end)

    %{pieces: pieces} =
      attrs
      |> Enum.into(%{
        pieces: WebLudo.Logic.Constants.initial_pieces()
      })

    Enum.each(pieces, fn p -> {:ok, _piece} = Logic.create_piece(game, p) end)
    game |> Repo.preload(:teams) |> Repo.preload(:players)
  end

  # NOTE: Doesn't account for duplicates
  def list_contents_equal?(l1, l2) do
    set1 = MapSet.new(l1)
    set2 = MapSet.new(l2)

    set1 == set2
  end
end
