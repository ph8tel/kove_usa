defmodule Kove.Repo.Migrations.EvolveOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :status, :string, null: false, default: "cart"
      add :shipping_name, :string
      add :shipping_address, :text
      add :tracking_number, :string
      add :shipped_at, :utc_datetime
      add :confirmed_at, :utc_datetime

      # Make previously required columns nullable for cart-based orders
      modify :customer_name, :string, null: true
      modify :customer_email, :string, null: true
      modify :customer_phone, :string, null: true

      # bike_id is no longer required (orders can be parts-only)
      modify :bike_id, :bigint, null: true
    end

    create index(:orders, [:user_id, :status])
  end
end
