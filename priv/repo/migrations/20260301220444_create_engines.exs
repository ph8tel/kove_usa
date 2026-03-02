defmodule Kove.Repo.Migrations.CreateEngines do
  use Ecto.Migration

  def change do
    create table(:engines) do
      add :platform_name, :string, null: false
      add :engine_type, :string, null: false
      add :displacement, :string, null: false
      add :bore_x_stroke, :string, null: false
      add :cooling, :string, null: false
      add :compression_ratio, :string
      add :fuel_system, :string, null: false
      add :transmission, :string, null: false
      add :clutch, :string, null: false
      add :starter, :string, null: false
      add :max_power, :string
      add :max_torque, :string

      timestamps(type: :utc_datetime)
    end
  end
end
