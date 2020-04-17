defmodule WebLudo.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :name, :string
      add :color, :string
      add :token, :string

      timestamps()
    end

  end
end
