defmodule WebKimble.Repo.Migrations.AddCanRaiseToPlayer do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :can_raise, :boolean
    end
  end
end
