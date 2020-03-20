defmodule WebKimble.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :name, :string
      add :code, :string

      timestamps()
    end

  end
end
