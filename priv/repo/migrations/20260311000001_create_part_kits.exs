defmodule Kove.Repo.Migrations.CreatePartKits do
  use Ecto.Migration

  def up do
    create table(:part_kits) do
      add :sku, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :price_cents, :integer, null: false
      add :active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:part_kits, [:sku])

    # Add vector column only if pgvector extension is available
    execute("""
    DO $$
    BEGIN
      ALTER TABLE part_kits ADD COLUMN embedding vector(768);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgvector not available, skipping part_kits embedding column';
    END
    $$;
    """)
  end

  def down do
    drop table(:part_kits)
  end
end
