defmodule Kove.Repo.Migrations.CreateDescriptions do
  use Ecto.Migration

  def up do
    create table(:descriptions) do
      add :bike_id, references(:bikes, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :body, :text, null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:descriptions, [:bike_id])
    create index(:descriptions, [:bike_id, :kind, :position])

    # Add vector column only if pgvector extension is available
    execute("""
    DO $$
    BEGIN
      ALTER TABLE descriptions ADD COLUMN embedding vector(1536);
      CREATE INDEX descriptions_embedding_index ON descriptions USING ivfflat (embedding);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgvector not available, skipping embedding column';
    END
    $$;
    """)
  end

  def down do
    drop table(:descriptions)
  end
end
