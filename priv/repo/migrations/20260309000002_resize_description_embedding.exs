defmodule Kove.Repo.Migrations.ResizeDescriptionEmbedding do
  use Ecto.Migration

  def up do
    # All embedding values are currently NULL — safe to retype in place.
    # nomic-embed-text-v1.5 produces 768-dimensional vectors.
    execute("ALTER TABLE descriptions ALTER COLUMN embedding TYPE vector(768)")
  end

  def down do
    execute("ALTER TABLE descriptions ALTER COLUMN embedding TYPE vector(1536)")
  end
end
