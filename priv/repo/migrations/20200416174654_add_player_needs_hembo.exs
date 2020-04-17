defmodule WebLudo.Repo.Migrations.AddPlayerNeedsHembo do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :needs_hembo, :boolean, default: false
    end
  end
end
