defmodule WebKimble.Networking.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:color, :name, :inserted_at]}  
  schema "players" do
    field :color, EctoAtom
    field :name, :string

    belongs_to :game, WebKimble.Networking.Game

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :color])
    |> validate_required([:name, :color])
  end
end
