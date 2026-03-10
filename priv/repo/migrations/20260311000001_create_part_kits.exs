defmodule Kove.Repo.Migrations.CreatePartKits do
  use Ecto.Migration

  def change do
    create table(:part_kits) do
      add :sku, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :price_cents, :integer, null: false
      add :active, :boolean, default: true, null: false
      add :embedding, :vector, size: 768

      timestamps(type: :utc_datetime)
    end

    create unique_index(:part_kits, [:sku])
  end
end
