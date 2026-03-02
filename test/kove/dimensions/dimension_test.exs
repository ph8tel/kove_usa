defmodule Kove.Dimensions.DimensionTest do
  use Kove.DataCase

  alias Kove.Dimensions.Dimension
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
      attrs = %{bike_id: bike.id}

      changeset = Dimension.changeset(%Dimension{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        weight: "320 lbs",
        weight_type: :dry,
        fuel_capacity: "8 Gallons (3 separate tanks)",
        estimated_range: "300+ Miles",
        overall_size: "86\" x 31\" x 55\"",
        wheelbase: "58.7\"",
        seat_height: "37.8\" (High Seat) / 36\" (Low Seat)",
        ground_clearance: "12.2\" (High Seat) / 10.6\" (Low Seat)"
      }

      changeset = Dimension.changeset(%Dimension{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with curb weight_type", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        weight: "350 lbs",
        weight_type: :curb
      }

      changeset = Dimension.changeset(%Dimension{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing bike_id" do
      attrs = %{weight: "320 lbs"}

      changeset = Dimension.changeset(%Dimension{}, attrs)
      refute changeset.valid?
      assert :bike_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "changeset allows nil optional fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        weight: nil,
        weight_type: nil,
        fuel_capacity: nil
      }

      changeset = Dimension.changeset(%Dimension{}, attrs)
      assert changeset.valid?
    end
  end
end
