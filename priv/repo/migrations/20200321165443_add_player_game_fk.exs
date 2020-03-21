defmodule WebKimble.Repo.Migrations.AddPlayerGameFk do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :game_id, references(:games)
    end

    create index(:players, [:game_id])
  end
end
