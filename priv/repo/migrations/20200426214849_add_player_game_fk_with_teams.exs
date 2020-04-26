defmodule WebLudo.Repo.Migrations.AddPlayerGameFkWithTeams do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :game_id, references(:games)
    end
  end
end
