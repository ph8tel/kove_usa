defmodule Kove.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :bike_id, references(:bikes, on_delete: :delete_all), null: false
      add :alt, :string, null: false
      add :url, :string, null: false
      add :position, :integer, null: false
      add :is_hero, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:images, [:bike_id])
  end
end
