defmodule Kove.ChassisSpecs.ChassisSpecTest do
  use Kove.DataCase

  alias Kove.ChassisSpecs.ChassisSpec
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

      changeset = ChassisSpec.changeset(%ChassisSpec{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        frame_type: "Steel Semi-Perimeter",
        front_suspension: "49mm YU-AN Upside Fork, Fully Adjustable",
        front_travel: "12\" (High Seat) / 10\" (Low Seat)",
        rear_suspension: "YU-AN Reservoir Monoshock, Fully Adjustable",
        rear_travel: "12\" (High Seat) / 10\" (Low Seat)",
        front_brake: "280mm Disc, 2-Piston Caliper, Selectable ABS",
        rear_brake: "240mm Disc, Single-Piston Caliper, Selectable ABS",
        abs_system: "Switchable (Front/Back) with memory function",
        wheels: "Spoked",
        tires: "Dunlop AT81F / AT81R",
        steering_angle: "38.5 Degrees",
        rake_angle: "28 Degrees",
        triple_clamp: "Aluminum"
      }

      changeset = ChassisSpec.changeset(%ChassisSpec{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing bike_id" do
      attrs = %{frame_type: "Steel Semi-Perimeter"}

      changeset = ChassisSpec.changeset(%ChassisSpec{}, attrs)
      refute changeset.valid?
      assert :bike_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "changeset allows nil optional fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        frame_type: nil,
        front_suspension: nil,
        abs_system: nil
      }

      changeset = ChassisSpec.changeset(%ChassisSpec{}, attrs)
      assert changeset.valid?
    end
  end
end
