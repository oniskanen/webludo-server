defmodule WebKimble.Networking.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :color, EctoAtom
    field :name, :string
    field :token, :string

    belongs_to :game, WebKimble.Networking.Game

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :color, :token])
    |> validate_required([:name, :color, :token])
  end
end
