defmodule WebKimble.Logic.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :color,
             :name,
             :inserted_at,
             :penalties,
             :has_finished,
             :can_raise,
             :new_raising_round
           ]}
  schema "players" do
    field :color, EctoAtom
    field :name, :string
    field :penalties, :integer, default: 0
    field :has_finished, :boolean, default: false
    field :can_raise, :boolean, default: true
    field :new_raising_round, :boolean, default: false
    field :needs_hembo, :boolean, default: false

    belongs_to :game, WebKimble.Logic.Game

    timestamps()
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [
      :name,
      :color,
      :penalties,
      :has_finished,
      :can_raise,
      :new_raising_round,
      :needs_hembo
    ])
    |> validate_required([
      :name,
      :color,
      :penalties,
      :has_finished,
      :can_raise,
      :new_raising_round,
      :needs_hembo
    ])
    |> validate_number(:penalties, greater_than_or_equal_to: 0)
  end
end
