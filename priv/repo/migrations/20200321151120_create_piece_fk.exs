defmodule WebLudo.Repo.Migrations.CreatePieceFk do
  use Ecto.Migration

  def change do
    create table(:pieces) do
      add :player_color, :string
      add :area, :string
      add :position_index, :integer
      add :game_state_id, references(:game_states, on_delete: :delete_all)
    end

    create index(:pieces, [:game_state_id])
  end
end
