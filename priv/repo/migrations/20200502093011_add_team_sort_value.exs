defmodule WebLudo.Repo.Migrations.AddTeamSortValue do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :sort_value, :integer
    end
  end
end
