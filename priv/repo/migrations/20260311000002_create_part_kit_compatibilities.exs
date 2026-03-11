defmodule Kove.Repo.Migrations.CreatePartKitCompatibilities do
  use Ecto.Migration

  def change do
    create table(:part_kit_compatibilities) do
      add :part_kit_id, references(:part_kits, on_delete: :delete_all), null: false
      add :engine_id, references(:engines, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:part_kit_compatibilities, [:part_kit_id, :engine_id])
    create index(:part_kit_compatibilities, [:engine_id])
  end
end
