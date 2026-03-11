defmodule Kove.Repo.Migrations.CreateOrderItems do
  use Ecto.Migration

  def change do
    create table(:order_items) do
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :part_kit_id, references(:part_kits, on_delete: :restrict)
      add :part_id, :bigint
      add :quantity, :integer, null: false, default: 1
      add :unit_price_cents, :integer, null: false
      add :name_snapshot, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:part_kit_id])
  end
end
