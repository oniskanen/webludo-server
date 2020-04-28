defmodule WebLudo.Repo.Migrations.AddPlayerTeamFk do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :team_id, references(:teams)
    end

    create index(:players, [:team_id])
  end
end
