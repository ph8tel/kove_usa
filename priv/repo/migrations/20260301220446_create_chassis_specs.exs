defmodule Kove.Repo.Migrations.CreateChassisSpecs do
  use Ecto.Migration

  def change do
    create table(:chassis_specs) do
      add :bike_id, references(:bikes, on_delete: :delete_all), null: false
      add :frame_type, :string
      add :front_suspension, :string
      add :front_travel, :string
      add :rear_suspension, :string
      add :rear_travel, :string
      add :front_brake, :string
      add :rear_brake, :string
      add :abs_system, :string
      add :wheels, :string
      add :tires, :string
      add :steering_angle, :string
      add :rake_angle, :string
      add :triple_clamp, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chassis_specs, [:bike_id])
  end
end
