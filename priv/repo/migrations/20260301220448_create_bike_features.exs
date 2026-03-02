defmodule Kove.Repo.Migrations.CreateBikeFeatures do
  use Ecto.Migration

  def change do
    create table(:bike_features) do
      add :bike_id, references(:bikes, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bike_features, [:bike_id, :name])
    create index(:bike_features, [:bike_id])
  end
end
