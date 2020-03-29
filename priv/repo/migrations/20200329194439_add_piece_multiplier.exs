defmodule WebKimble.Repo.Migrations.AddPieceMultiplier do
  use Ecto.Migration

  def change do
    alter table(:pieces) do
      add :multiplier, :integer, default: 1
    end
  end
end
