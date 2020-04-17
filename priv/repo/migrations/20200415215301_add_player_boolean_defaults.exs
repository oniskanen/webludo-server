defmodule WebLudo.Repo.Migrations.AddPlayerBooleanDefaults do
  use Ecto.Migration

  def change do
    alter table(:players) do
      modify :can_raise, :boolean, default: true
      modify :has_finished, :boolean, default: false
    end
  end
end
