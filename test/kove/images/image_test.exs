defmodule Kove.Images.ImageTest do
  use Kove.DataCase

  alias Kove.Images.Image
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
        url: "https://example.com/image.jpg"
      }

      changeset = Image.changeset(%Image{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        alt: "2026 Kove 800X Rally Action Shot",
        url: "https://example.com/image.jpg",
        position: 1,
        is_hero: true
      }

      changeset = Image.changeset(%Image{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing bike_id" do
      attrs = %{url: "https://example.com/image.jpg"}

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert :bike_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing url", %{bike: bike} do
      attrs = %{bike_id: bike.id}

      changeset = Image.changeset(%Image{}, attrs)
      refute changeset.valid?
      assert :url in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "changeset allows nil optional fields", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        url: "https://example.com/image.jpg",
        alt: nil,
        position: nil,
        is_hero: nil
      }

      changeset = Image.changeset(%Image{}, attrs)
      assert changeset.valid?
    end

    test "changeset defaults is_hero to false", %{bike: bike} do
      attrs = %{
        bike_id: bike.id,
        url: "https://example.com/image.jpg"
      }

      changeset = Image.changeset(%Image{}, attrs)
      # The default value is set in the schema, check the struct after apply_changes
      image = Ecto.Changeset.apply_changes(changeset)
      assert image.is_hero == false
    end
  end
end
