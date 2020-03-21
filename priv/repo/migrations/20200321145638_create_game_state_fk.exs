defmodule WebKimble.Repo.Migrations.CreateGameStateFk do
  use Ecto.Migration

  def change do
    create table(:game_states) do
      add :current_player, :string
      add :game_id, references(:games, on_delete: :delete_all)
      timestamps()
    end

    create index(:game_states, [:game_id])
  end
end
