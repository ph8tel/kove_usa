defmodule Kove.Orders.OrderTest do
  use Kove.DataCase

  alias Kove.Orders.Order
  alias Kove.Bikes.Bike
  alias Kove.Engines.Engine

  setup do
    engine_attrs = %{
      platform_name: "800X (799cc DOHC Parallel Twin)",
      engine_type: "Twin Cylinder, DOHC",
      displacement: "799cc",
      bore_x_stroke: "88mm × 65.7mm",
      cooling: "Liquid-Cooled",
      fuel_system: "Bosch EFI",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
      starter: "Electric"
    }

    {:ok, engine} = Kove.Repo.insert(Engine.changeset(%Engine{}, engine_attrs))

    bike_attrs = %{
      engine_id: engine.id,
      name: "2026 Kove 800X Rally",
      year: 2026,
      variant: "Rally",
      slug: "2026-kove-800x-rally",
      status: :street_legal,
      category: :adv
    }

    {:ok, bike} = Kove.Repo.insert(Bike.changeset(%Bike{}, bike_attrs))
    {:ok, bike: bike}
  end

  describe "changeset/2" do
    test "valid changeset with required fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        customer_name: "John Doe",
        customer_email: "john@example.com"
      }

      changeset = Order.changeset(%Order{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        customer_name: "John Doe",
        customer_email: "john@example.com",
        customer_phone: "+1-555-123-4567",
        notes: "I'd like the high seat model in red."
      }

      changeset = Order.changeset(%Order{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing bike_id" do
      attrs = %{
        customer_name: "John Doe",
        customer_email: "john@example.com"
      }

      changeset = Order.changeset(%Order{}, attrs)
      refute changeset.valid?
      assert :bike_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing customer_name", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        customer_email: "john@example.com"
      }

      changeset = Order.changeset(%Order{}, attrs)
      refute changeset.valid?
      assert :customer_name in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing customer_email", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        customer_name: "John Doe"
      }

      changeset = Order.changeset(%Order{}, attrs)
      refute changeset.valid?
      assert :customer_email in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "valid email formats", %{bike: bike} do
      valid_emails = [
        "user@example.com",
        "john.doe@example.co.uk",
        "support+tag@example.com"
      ]

      Enum.each(valid_emails, fn email ->
        attrs = %{
          bike_id: bike.id,
          customer_name: "John Doe",
          customer_email: email
        }

        changeset = Order.changeset(%Order{}, attrs)
        assert changeset.valid?, "Email #{email} should be valid"
      end)
    end

    test "changeset allows nil optional fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        customer_name: "John Doe",
        customer_email: "john@example.com",
        customer_phone: nil,
        notes: nil
      }

      changeset = Order.changeset(%Order{}, attrs)
      assert changeset.valid?
    end
  end
end
