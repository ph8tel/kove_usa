defmodule Kove.Repo.Migrations.ResizeDescriptionEmbedding do
  use Ecto.Migration

  def up do
    # All embedding values are currently NULL — safe to retype in place.
    # nomic-embed-text-v1.5 produces 768-dimensional vectors.
    # Guarded: silently skips if pgvector wasn't installed (column won't exist).
    execute("""
    DO $$
    BEGIN
      ALTER TABLE descriptions ALTER COLUMN embedding TYPE vector(768);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgvector not available or column missing, skipping embedding resize';
    END
    $$;
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      ALTER TABLE descriptions ALTER COLUMN embedding TYPE vector(1536);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgvector not available or column missing, skipping embedding resize rollback';
    END
    $$;
    """)
  end
end
