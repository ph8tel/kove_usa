defmodule Kove.Repo.Migrations.AddGoogleIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :google_id, :string, size: 255
    end

    create unique_index(:users, [:google_id])
  end
end
