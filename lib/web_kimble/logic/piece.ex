defmodule WebKimble.Logic.Piece do
    use Ecto.Schema
    import Ecto.Changeset


    # Piece has a color and a area and position_index (mines, doubles etc. later on)
    # Color is a lowercase string. Area is one of :home, :play or :goal
    # Indexing in :home and :goal is 0 to 3.
    # Indexing in :play starts with red start = 0.
    # Color order on board is red -> blue -> yellow -> green
    # There are 5 positions between each start position, giving a total of 24 board positions
    # 0 = red start, 6 = blue start, 12 = yellow start, 18 = green start  

    schema "pieces" do
        field :position_index, :integer
        field :area, EctoAtom
        field :player_color, EctoAtom
        belongs_to :game_state, WebKimble.Logic.GameState

    end

    def changeset(piece, attrs) do
        piece
        |> cast(attrs, [:position_index, :area, :player_color])
        |> validate_required([:position_index, :area, :player_color])
    end
end