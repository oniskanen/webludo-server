defmodule WebKimble.Logic.GameState do
    use Ecto.Schema
    import Ecto.Changeset

    @derive {Jason.Encoder, only: [:current_player, :pieces]}
    schema "game_states" do
        field :current_player, EctoAtom
        has_many :pieces, WebKimble.Logic.Piece
        belongs_to :game, WebKimble.Networking.Game

        timestamps()
    end

    @doc false
    def changeset(game_state, attrs) do
        game_state
        |> cast(attrs, [:current_player])
        |> validate_required([:current_player])
    end
end