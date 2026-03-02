defmodule Kove.Repo.Migrations.CreateBikes do
  use Ecto.Migration

  def change do
    create table(:bikes) do
      add :engine_id, references(:engines, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :year, :integer, null: false
      add :variant, :string, null: false
      add :slug, :string, null: false
      add :status, :string, null: false
      add :category, :string, null: false
      add :msrp_cents, :integer
      add :hero_image_url, :string
      add :exhaust_override, :string
      add :sprocket_override, :string
      add :ecu_override, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bikes, [:slug])
    create index(:bikes, [:engine_id])
    create index(:bikes, [:category])
    create index(:bikes, [:status])
  end
end
