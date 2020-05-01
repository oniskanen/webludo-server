defmodule WebLudo.Logic.Team do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :color,
             :name,
             :penalties,
             :has_finished,
             :can_raise,
             :new_raising_round,
             :id
           ]}

  schema "teams" do
    field :color, EctoAtom
    field :name, :string
    field :penalties, :integer, default: 0
    field :has_finished, :boolean, default: false
    field :can_raise, :boolean, default: true
    field :new_raising_round, :boolean, default: false
    field :needs_hembo, :boolean, default: false

    belongs_to :game, WebLudo.Logic.Game
    has_many :players, WebLudo.Logic.Player

    timestamps()
  end

  @doc false
  def changeset(team, attrs) do
    team
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
