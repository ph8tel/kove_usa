defmodule Kove.Bikes.BikeTest do
  use Kove.DataCase

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
    {:ok, engine: engine}
  end

  describe "changeset/2" do
    test "valid changeset with required fields", %{engine: engine} do
      attrs = %{
        engine_id: engine.id,
        name: "2026 Kove 800X Rally",
        year: 2026,
        variant: "Rally",
        slug: "2026-kove-800x-rally",
        status: :street_legal,
        category: :adv
      }

      changeset = Bike.changeset(%Bike{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields", %{engine: engine} do
      attrs = %{
        engine_id: engine.id,
        name: "2026 Kove 800X Rally",
        year: 2026,
        variant: "Rally",
        slug: "2026-kove-800x-rally",
        status: :street_legal,
        category: :adv,
        msrp_cents: 1299900,
        hero_image_url: "https://example.com/hero.jpg"
      }

      changeset = Bike.changeset(%Bike{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing engine_id" do
      attrs = %{
        name: "2026 Kove 800X Rally",
        slug: "2026-kove-800x-rally",
        category: :adv
      }

      changeset = Bike.changeset(%Bike{}, attrs)
      refute changeset.valid?
      assert :engine_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing name" do
      attrs = %{
        engine_id: 1,
        slug: "2026-kove-800x-rally",
        category: :adv
      }

      changeset = Bike.changeset(%Bike{}, attrs)
      refute changeset.valid?
      assert :name in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing slug", %{engine: engine} do
      attrs = %{
        engine_id: engine.id,
        name: "2026 Kove 800X Rally",
        category: :adv
      }

      changeset = Bike.changeset(%Bike{}, attrs)
      refute changeset.valid?
      assert :slug in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing category", %{engine: engine} do
      attrs = %{
        engine_id: engine.id,
        name: "2026 Kove 800X Rally",
        slug: "2026-kove-800x-rally"
      }

      changeset = Bike.changeset(%Bike{}, attrs)
      refute changeset.valid?
      assert :category in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "unique slug constraint", %{engine: engine} do
      attrs = %{
        engine_id: engine.id,
        name: "2026 Kove 800X Rally",
        year: 2026,
        variant: "Rally",
        slug: "2026-kove-800x-rally",
        status: :street_legal,
        category: :adv
      }

      {:ok, _bike} = Kove.Repo.insert(Bike.changeset(%Bike{}, attrs))

      # Attempt to insert another bike with the same slug
      changeset = Bike.changeset(%Bike{}, attrs)

      assert {:error, changeset} = Kove.Repo.insert(changeset)
      assert "has already been taken" in Enum.map(changeset.errors, fn {_field, {msg, _}} -> msg end)
    end
  end
end
