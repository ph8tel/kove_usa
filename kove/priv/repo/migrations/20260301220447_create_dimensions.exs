defmodule Kove.Repo.Migrations.CreateDimensions do
  use Ecto.Migration

  def change do
    create table(:dimensions) do
      add :bike_id, references(:bikes, on_delete: :delete_all), null: false
      add :weight, :string
      add :weight_type, :string
      add :fuel_capacity, :string
      add :estimated_range, :string
      add :overall_size, :string
      add :wheelbase, :string
      add :seat_height, :string
      add :ground_clearance, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:dimensions, [:bike_id])
  end
end
