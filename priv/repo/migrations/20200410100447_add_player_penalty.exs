defmodule WebLudo.Repo.Migrations.AddPlayerPenalty do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :penalties, :integer, default: 0
    end
  end
end
