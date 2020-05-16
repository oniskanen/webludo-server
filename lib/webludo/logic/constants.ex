defmodule WebLudo.Logic.Constants do
  @team_colors [:red, :blue, :yellow, :green]
  @short_track_indices [0, 1, 2, 3]

  @team_order %{
    red: :blue,
    blue: :yellow,
    yellow: :green,
    green: :red
  }

  def initial_pieces do
    for p <- @team_colors,
        i <- @short_track_indices,
        do: %{team_color: p, position_index: i, area: :home}
  end

  def play_track_length do
    28
  end

  def goal_track_length do
    4
  end

  def max_rolls do
    3
  end

  def get_home_space_index(team_color) do
    case team_color do
      :red -> 0
      :blue -> 7
      :yellow -> 14
      :green -> 21
    end
  end

  def team_colors do
    @team_colors
  end

  def next_team(color) do
    @team_order[color]
  end

  def team_count do
    length(@team_colors)
  end

  def team_piece_count do
    4
  end

  def start_index_list, do: @short_track_indices

  def goal_index_list, do: @short_track_indices

  def piece_name(multiplier) do
    case multiplier do
      1 -> "single"
      2 -> "double"
      3 -> "triple"
      4 -> "quatro"
    end
  end

  def multiplier_verb(multiplier) do
    case multiplier do
      2 -> "doubles"
      3 -> "triples"
      4 -> "quatros"
    end
  end

  def min_team_count, do: 1
end
