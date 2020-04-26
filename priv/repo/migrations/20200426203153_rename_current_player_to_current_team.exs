defmodule WebLudo.Repo.Migrations.RenameCurrentPlayerToCurrentTeam do
  use Ecto.Migration

  def change do
    rename table(:games), :current_player, to: :current_team
  end
end
