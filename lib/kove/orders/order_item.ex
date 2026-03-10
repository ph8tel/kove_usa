defmodule Kove.Orders.OrderItem do
  @moduledoc """
  Line item within an order.

  Captures a snapshot of the item name and unit price at time of addition,
  so the order history remains accurate even if part kit prices change.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "order_items" do
    field :quantity, :integer, default: 1
    field :unit_price_cents, :integer
    field :name_snapshot, :string
    field :part_id, :integer

    belongs_to :order, Kove.Orders.Order
    belongs_to :part_kit, Kove.Parts.PartKit

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:quantity, :unit_price_cents, :name_snapshot, :part_kit_id, :part_id])
    |> validate_required([:quantity, :unit_price_cents, :name_snapshot])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price_cents, greater_than_or_equal_to: 0)
  end
end
