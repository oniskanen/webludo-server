defmodule WebLudo.Repo.Migrations.AddNewRaisingRoundToPlayer do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :new_raising_round, :boolean, default: false
    end
  end
end
