defmodule WebLudo.Repo.Migrations.MergeGameStateToGame do
  use Ecto.Migration

  def change do
    drop index(:pieces, [:game_state_id])

    alter table(:pieces) do
      remove :game_state_id
      add :game_id, references(:games, on_delete: :delete_all)
    end

    create index(:pieces, [:game_id])

    alter table(:games) do
      add :roll, :integer, default: 0
      add :roll_count, :integer, default: 0
    end

    drop index(:game_states, [:game_id])
    drop table(:game_states)
  end
end
