defmodule Kove.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :bike_id, references(:bikes, on_delete: :restrict), null: false
      add :customer_name, :string, null: false
      add :customer_email, :string, null: false
      add :customer_phone, :string, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:bike_id])
  end
end
