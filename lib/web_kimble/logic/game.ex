defmodule WebKimble.Logic.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [:code, :name, :players, :current_player, :pieces, :roll, :roll_count]}
  schema "games" do
    field :code, :string
    field :name, :string

    has_many :players, WebKimble.Logic.Player
    field :current_player, EctoAtom
    has_many :pieces, WebKimble.Logic.Piece
    field :roll, :integer
    field :roll_count, :integer
    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :code, :current_player, :roll, :roll_count])
    |> validate_required([:name, :code, :current_player])
  end
end
