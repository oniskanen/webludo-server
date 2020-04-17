defmodule WebLudo.Repo.Migrations.AddHasFinishedToPlayer do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :has_finished, :boolean
    end
  end
end
