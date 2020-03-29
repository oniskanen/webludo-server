defmodule WebKimble.Networking.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:code, :name, :players, :game_state]}
  schema "games" do
    field :code, :string
    field :name, :string

    has_many :players, WebKimble.Networking.Player
    has_one :game_state, WebKimble.Logic.GameState

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:name, :code])
    |> validate_required([:name, :code])
  end
end
