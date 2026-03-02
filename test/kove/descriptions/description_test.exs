defmodule Kove.Descriptions.DescriptionTest do
  use Kove.DataCase

  alias Kove.Descriptions.Description
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
        kind: :marketing,
        body: "The heart of the KOVE 800X is a powerful 799cc twin engine..."
      }

      changeset = Description.changeset(%Description{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        kind: :marketing,
        body: "The heart of the KOVE 800X is a powerful 799cc twin engine...",
        position: 1,
        embedding: nil
      }

      changeset = Description.changeset(%Description{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with maintenance kind", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        kind: :maintenance,
        body: "Regular oil changes are recommended every 3,000 miles..."
      }

      changeset = Description.changeset(%Description{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing bike_id" do
      attrs = %{
        kind: :marketing,
        body: "The heart of the KOVE 800X is a powerful 799cc twin engine..."
      }

      changeset = Description.changeset(%Description{}, attrs)
      refute changeset.valid?
      assert :bike_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing kind", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        body: "The heart of the KOVE 800X is a powerful 799cc twin engine..."
      }

      changeset = Description.changeset(%Description{}, attrs)
      refute changeset.valid?
      assert :kind in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing body", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        kind: :marketing
      }

      changeset = Description.changeset(%Description{}, attrs)
      refute changeset.valid?
      assert :body in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "changeset allows nil optional fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        kind: :marketing,
        body: "The heart of the KOVE 800X is a powerful 799cc twin engine...",
        position: nil,
        embedding: nil
      }

      changeset = Description.changeset(%Description{}, attrs)
      assert changeset.valid?
    end
  end
end
