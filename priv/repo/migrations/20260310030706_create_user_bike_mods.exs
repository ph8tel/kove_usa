defmodule Kove.Repo.Migrations.CreateUserBikeMods do
  use Ecto.Migration

  def up do
    # Create the mod_type enum
    execute """
    CREATE TYPE mod_type AS ENUM (
      'exhaust',
      'gearing',
      'suspension',
      'clutch',
      'engine',
      'electronics',
      'intake',
      'controls',
      'tires',
      'protection',
      'lighting'
    )
    """

    create table(:user_bike_mods) do
      add :user_bike_id, references(:user_bikes, on_delete: :delete_all), null: false
      add :mod_type, :mod_type, null: false
      add :description, :text, null: false
      add :brand, :string
      add :cost_cents, :integer
      add :installed_at, :date
      add :rating, :integer
      add :position, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:user_bike_mods, [:user_bike_id])

    # Add vector column only if pgvector extension is available
    execute("""
    DO $$
    BEGIN
      ALTER TABLE user_bike_mods ADD COLUMN embedding vector(768);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'pgvector not available, skipping user_bike_mods embedding column';
    END
    $$;
    """)
  end

  def down do
    drop table(:user_bike_mods)
    execute "DROP TYPE mod_type"
  end
end
