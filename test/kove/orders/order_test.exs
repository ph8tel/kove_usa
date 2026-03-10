defmodule Kove.Orders.OrderTest do
  use Kove.DataCase

  alias Kove.Orders.Order

  describe "cart_changeset/2" do
    test "valid cart changeset" do
      changeset = Order.cart_changeset(%Order{}, %{status: "cart"})
      assert changeset.valid?
    end

    test "defaults to cart status when no attrs given" do
      changeset = Order.cart_changeset(%Order{}, %{})
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == "cart"
    end

    test "invalid with bad status" do
      changeset = Order.cart_changeset(%Order{}, %{status: "invalid"})
      refute changeset.valid?
    end
  end

  describe "confirm_changeset/2" do
    test "valid confirm changeset" do
      attrs = %{
        status: "pending",
        customer_name: "John Doe",
        customer_email: "john@example.com"
      }

      changeset = Order.confirm_changeset(%Order{}, attrs)
      assert changeset.valid?
    end

    test "valid with all shipping fields" do
      attrs = %{
        status: "pending",
        customer_name: "John Doe",
        customer_email: "john@example.com",
        customer_phone: "+1-555-123-4567",
        shipping_name: "John Doe",
        shipping_address: "123 Main St",
        notes: "Leave at door"
      }

      changeset = Order.confirm_changeset(%Order{}, attrs)
      assert changeset.valid?
    end

    test "invalid without customer_name" do
      attrs = %{status: "pending", customer_email: "john@example.com"}
      changeset = Order.confirm_changeset(%Order{}, attrs)
      refute changeset.valid?
      assert :customer_name in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid without customer_email" do
      attrs = %{status: "pending", customer_name: "John Doe"}
      changeset = Order.confirm_changeset(%Order{}, attrs)
      refute changeset.valid?
      assert :customer_email in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid email format" do
      attrs = %{status: "pending", customer_name: "John", customer_email: "nope"}
      changeset = Order.confirm_changeset(%Order{}, attrs)
      refute changeset.valid?
      assert :customer_email in Enum.map(changeset.errors, fn {field, _} -> field end)
    end
  end

  describe "status_changeset/2" do
    test "valid status transition" do
      changeset = Order.status_changeset(%Order{}, %{status: "shipped"})
      assert changeset.valid?
    end

    test "includes tracking_number and shipped_at" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        Order.status_changeset(%Order{}, %{
          status: "shipped",
          tracking_number: "1Z999AA10123456784",
          shipped_at: now
        })

      assert changeset.valid?
    end

    test "invalid status value" do
      changeset = Order.status_changeset(%Order{}, %{status: "bogus"})
      refute changeset.valid?
    end
  end

  describe "statuses/0" do
    test "returns all valid statuses" do
      statuses = Order.statuses()
      assert "cart" in statuses
      assert "pending" in statuses
      assert "confirmed" in statuses
      assert "shipped" in statuses
      assert "delivered" in statuses
      assert "cancelled" in statuses
    end
  end
end
