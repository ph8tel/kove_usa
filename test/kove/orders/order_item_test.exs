defmodule Kove.Orders.OrderItemTest do
  use Kove.DataCase

  alias Kove.Orders.OrderItem

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{quantity: 1, unit_price_cents: 4999, name_snapshot: "Oil Change Kit"}
      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with part_kit_id" do
      attrs = %{
        quantity: 2,
        unit_price_cents: 4999,
        name_snapshot: "Oil Change Kit",
        part_kit_id: 1
      }

      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      assert changeset.valid?
    end

    test "defaults quantity to 1 when not provided" do
      attrs = %{unit_price_cents: 4999, name_snapshot: "Kit"}
      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :quantity) == 1
    end

    test "invalid without unit_price_cents" do
      attrs = %{quantity: 1, name_snapshot: "Kit"}
      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      refute changeset.valid?
    end

    test "invalid without name_snapshot" do
      attrs = %{quantity: 1, unit_price_cents: 4999}
      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      refute changeset.valid?
    end

    test "invalid with zero quantity" do
      attrs = %{quantity: 0, unit_price_cents: 4999, name_snapshot: "Kit"}
      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      refute changeset.valid?
    end

    test "invalid with negative unit_price_cents" do
      attrs = %{quantity: 1, unit_price_cents: -100, name_snapshot: "Kit"}
      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      refute changeset.valid?
    end

    test "zero unit_price_cents is valid" do
      attrs = %{quantity: 1, unit_price_cents: 0, name_snapshot: "Free Kit"}
      changeset = OrderItem.changeset(%OrderItem{}, attrs)
      assert changeset.valid?
    end
  end
end
