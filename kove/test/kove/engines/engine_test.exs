defmodule Kove.Engines.EngineTest do
  use Kove.DataCase

  alias Kove.Engines.Engine

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
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

      changeset = Engine.changeset(%Engine{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields" do
      attrs = %{
        platform_name: "800X (799cc DOHC Parallel Twin)",
        engine_type: "Twin Cylinder, DOHC",
        displacement: "799cc",
        bore_x_stroke: "88mm × 65.7mm",
        cooling: "Liquid-Cooled",
        compression_ratio: "14:1",
        fuel_system: "Bosch EFI",
        transmission: "6-Speed",
        clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
        starter: "Electric",
        max_power: "95 HP",
        max_torque: "77 ft-lbs"
      }

      changeset = Engine.changeset(%Engine{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing platform_name" do
      attrs = %{
        engine_type: "Twin Cylinder, DOHC",
        displacement: "799cc",
        bore_x_stroke: "88mm × 65.7mm",
        cooling: "Liquid-Cooled",
        fuel_system: "Bosch EFI",
        transmission: "6-Speed",
        clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
        starter: "Electric"
      }

      changeset = Engine.changeset(%Engine{}, attrs)
      refute changeset.valid?
      assert :platform_name in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing engine_type" do
      attrs = %{
        platform_name: "800X (799cc DOHC Parallel Twin)",
        displacement: "799cc",
        bore_x_stroke: "88mm × 65.7mm",
        cooling: "Liquid-Cooled",
        fuel_system: "Bosch EFI",
        transmission: "6-Speed",
        clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
        starter: "Electric"
      }

      changeset = Engine.changeset(%Engine{}, attrs)
      refute changeset.valid?
      assert :engine_type in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing displacement" do
      attrs = %{
        platform_name: "800X (799cc DOHC Parallel Twin)",
        engine_type: "Twin Cylinder, DOHC",
        bore_x_stroke: "88mm × 65.7mm",
        cooling: "Liquid-Cooled",
        fuel_system: "Bosch EFI",
        transmission: "6-Speed",
        clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
        starter: "Electric"
      }

      changeset = Engine.changeset(%Engine{}, attrs)
      refute changeset.valid?
      assert :displacement in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "changeset allows nil optional fields" do
      attrs = %{
        platform_name: "MX450 (449cc SOHC Single)",
        engine_type: "Single Cylinder, SOHC",
        displacement: "449.9cc",
        bore_x_stroke: "96mm x 62.15mm",
        cooling: "Liquid-Cooled",
        fuel_system: "Bosch EFI",
        transmission: "5-Speed",
        clutch: "Oil Bath, Multi-Disc, Hydraulic-Actuated",
        starter: "Electric",
        compression_ratio: nil,
        max_power: nil,
        max_torque: nil
      }

      changeset = Engine.changeset(%Engine{}, attrs)
      assert changeset.valid?
    end
  end
end
