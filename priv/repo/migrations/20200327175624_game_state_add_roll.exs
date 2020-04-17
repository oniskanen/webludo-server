defmodule WebLudo.Repo.Migrations.GameStateAddRoll do
  use Ecto.Migration

  def change do
    alter table(:game_states) do
      add :roll, :integer, default: 0
      add :roll_count, :integer, default: 0
    end
  end
end
