defmodule Kove.Repo.Migrations.AddHandleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :handle, :string
      add :handle_locked, :boolean, default: false, null: false
    end

    create unique_index(:users, [:handle])
  end
end
