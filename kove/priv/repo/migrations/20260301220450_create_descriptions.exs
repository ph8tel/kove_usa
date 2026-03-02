defmodule Kove.Repo.Migrations.CreateDescriptions do
  use Ecto.Migration

  def change do
    create table(:descriptions) do
      add :bike_id, references(:bikes, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :body, :text, null: false
      add :position, :integer, null: false
      add :embedding, :vector, size: 1536

      timestamps(type: :utc_datetime)
    end

    create index(:descriptions, [:bike_id])
    create index(:descriptions, [:bike_id, :kind, :position])
    create index(:descriptions, [:embedding], using: :ivfflat)
  end
end
