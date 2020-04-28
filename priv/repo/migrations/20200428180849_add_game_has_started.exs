defmodule WebLudo.Repo.Migrations.AddGameHasStarted do
  use Ecto.Migration

  def change do
    alter table(:games) do
      add :has_started, :boolean, default: false
    end
  end
end
