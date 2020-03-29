defmodule WebKimble.Logic.GameState do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:current_player, :pieces, :roll, :roll_count]}
  schema "game_states" do
    field :current_player, EctoAtom
    has_many :pieces, WebKimble.Logic.Piece
    belongs_to :game, WebKimble.Networking.Game
    field :roll, :integer
    field :roll_count, :integer

    timestamps()
  end

  @doc false
  def changeset(game_state, attrs) do
    game_state
    |> cast(attrs, [:current_player, :roll, :roll_count])
    |> validate_required([:current_player])
  end
end
