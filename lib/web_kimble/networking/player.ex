defmodule WebKimble.Networking.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:color, :name, :inserted_at, :penalties]}
  schema "players" do
    field :color, EctoAtom
    field :name, :string
    field :penalties, :integer, default: 0

    belongs_to :game, WebKimble.Networking.Game

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :color, :penalties])
    |> validate_required([:name, :color, :penalties])
  end
end
