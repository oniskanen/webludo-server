defmodule WebLudo.Repo.Migrations.RemovePlayerToken do
  use Ecto.Migration

  def change do
    alter table(:players) do
      remove :token
    end
  end
end
