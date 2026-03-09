defmodule Kove.Repo.Migrations.FixMx450EngineId do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE bikes
    SET engine_id = (
      SELECT id FROM engines
      WHERE platform_name = 'MX450 (449cc SOHC Single)'
      LIMIT 1
    )
    WHERE slug LIKE '%mx450%'
    """)
  end

  def down do
    execute("""
    UPDATE bikes
    SET engine_id = (
      SELECT id FROM engines
      WHERE platform_name = '800X (799cc DOHC Parallel Twin)'
      LIMIT 1
    )
    WHERE slug LIKE '%mx450%'
    """)
  end
end
