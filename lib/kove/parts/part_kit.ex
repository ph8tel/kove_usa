defmodule Kove.Parts.PartKit do
  @moduledoc """
  Schema for part kits — bundled maintenance/upgrade packages.

  Each kit is compatible with one or more engine platforms via
  the `part_kit_compatibilities` join table.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "part_kits" do
    field :sku, :string
    field :name, :string
    field :description, :string
    field :price_cents, :integer
    field :active, :boolean, default: true
    field :embedding, Pgvector.Ecto.Vector

    has_many :compatibilities, Kove.Parts.PartKitCompatibility
    has_many :engines, through: [:compatibilities, :engine]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(part_kit, attrs) do
    part_kit
    |> cast(attrs, [:sku, :name, :description, :price_cents, :active])
    |> validate_required([:sku, :name, :price_cents])
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
    |> unique_constraint(:sku)
  end
end
