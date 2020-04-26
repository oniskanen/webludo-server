defmodule WebLudo.Logic.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [:code, :name, :players, :current_team, :pieces, :roll, :roll_count]}
  schema "games" do
    field :code, :string
    field :name, :string

    has_many :players, WebLudo.Logic.Player
    field :current_team, EctoAtom
    has_many :pieces, WebLudo.Logic.Piece
    field :roll, :integer
    field :roll_count, :integer
    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :code, :current_team, :roll, :roll_count])
    |> validate_required([:name, :code, :current_team])
  end
end
