defmodule Kove.Repo.Migrations.EnablePgvector do
  use Ecto.Migration

  def up do
    # pgvector may not be available on all Postgres providers (e.g. Fly managed Postgres).
    # Embeddings are optional — the app works fine without them.
    execute("""
    DO $$
    BEGIN
      CREATE EXTENSION IF NOT EXISTS vector;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgvector extension not available, skipping';
    END
    $$;
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      DROP EXTENSION IF EXISTS vector;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END
    $$;
    """)
  end
end
