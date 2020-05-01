defmodule WebLudo.Logic.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:name]}

  schema "players" do
    field :name, :string

    belongs_to :game, WebLudo.Logic.Game
    belongs_to :team, WebLudo.Logic.Team

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:name, :team_id])
    |> validate_required([:name])
  end
end
