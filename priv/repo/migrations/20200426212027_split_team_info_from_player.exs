defmodule WebLudo.Repo.Migrations.SplitTeamInfoFromPlayer do
  use Ecto.Migration

  def change do
    rename table(:players), to: table(:teams)

    create table(:players) do
      add :name, :string
      add :color, :string

      timestamps()
    end

    rename table(:pieces), :player_color, to: :team_color
  end
end
