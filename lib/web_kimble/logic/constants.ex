defmodule WebKimble.Logic.Constants do
  @player_colors [:red, :blue, :yellow, :green]
  # @areas [:home, :play, :goal]
  @starting_indices [0, 1, 2, 3]

  @player_order %{
    red: :blue,
    blue: :yellow,
    yellow: :green,
    green: :red
  }
  def initial_pieces do
    for p <- @player_colors,
        i <- @starting_indices,
        do: %{player_color: p, position_index: i, area: :home}
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

  def get_home_space_index(player_color) do
    case player_color do
      :red -> 0
      :blue -> 7
      :yellow -> 14
      :green -> 21
    end
  end

  def player_colors do
    @player_colors
  end

  def next_player(color) do
    @player_order[color]
  end

  def player_count do
    length(@player_colors)
  end

  def player_piece_count do
    4
  end

  def goal_index_list do
    [0, 1, 2, 3]
  end
end
