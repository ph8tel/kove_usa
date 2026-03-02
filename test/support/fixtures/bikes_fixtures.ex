defmodule Kove.BikesFixtures do
  @moduledoc """
  This module defines test fixtures for creating bike-related entities.

  Centralizes common test data setup to reduce duplication across test files.
  """

  alias Kove.Repo
  alias Kove.Engines.Engine
  alias Kove.Bikes.Bike
  alias Kove.ChassisSpecs.ChassisSpec
  alias Kove.Dimensions.Dimension
  alias Kove.BikeFeatures.BikeFeature
  alias Kove.Images.Image
  alias Kove.Descriptions.Description

  @doc """
  Creates an engine fixture with optional attribute overrides.

  ## Examples

      engine = engine_fixture()
      engine = engine_fixture(%{displacement: "450cc"})
  """
  def engine_fixture(attrs \\ %{}) do
    defaults = %{
      platform_name: "800X (799cc DOHC Parallel Twin)",
      engine_type: "Twin Cylinder, DOHC",
      displacement: "799cc",
      bore_x_stroke: "88mm × 65.7mm",
      cooling: "Liquid-Cooled",
      fuel_system: "Bosch EFI",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc",
      starter: "Electric"
    }

    {:ok, engine} =
      %Engine{}
      |> Engine.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    engine
  end

  @doc """
  Creates a bike fixture with optional engine and attribute overrides.

  If no engine is provided, creates a default engine.

  ## Examples

      bike = bike_fixture()
      bike = bike_fixture(nil, %{name: "Custom Bike"})

      engine = engine_fixture()
      bike = bike_fixture(engine, %{variant: "Pro"})
  """
  def bike_fixture(engine \\ nil, attrs \\ %{}) do
    engine = engine || engine_fixture()

    defaults = %{
      engine_id: engine.id,
      name: "2026 Kove 800X Pro",
      year: 2026,
      variant: "Pro",
      slug: "2026-kove-800x-pro",
      status: :street_legal,
      category: :adv,
      msrp_cents: 1_299_900,
      hero_image_url: "https://example.com/hero.jpg"
    }

    {:ok, bike} =
      %Bike{}
      |> Bike.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    bike
  end

  @doc """
  Creates a fully preloaded bike fixture (like Bikes.get_bike!/1 returns).

  This includes all associations: engine, chassis_spec, dimension, bike_features,
  images, and descriptions.

  ## Examples

      bike = bike_fixture_full()
      bike = bike_fixture_full(%{bike: %{name: "Custom"}, chassis: %{frame: "Custom Frame"}})
  """
  def bike_fixture_full(attrs \\ %{}) do
    bike_attrs = Map.get(attrs, :bike, %{})
    chassis_attrs = Map.get(attrs, :chassis, %{})
    dimension_attrs = Map.get(attrs, :dimension, %{})
    features_attrs = Map.get(attrs, :features, [])
    images_attrs = Map.get(attrs, :images, [])
    descriptions_attrs = Map.get(attrs, :descriptions, [])

    engine = engine_fixture()
    bike = bike_fixture(engine, bike_attrs)

    # Create chassis spec
    chassis_defaults = %{
      bike_id: bike.id,
      frame: "High-strength Steel",
      front_suspension: "USD Fork, 43mm, Fully Adjustable",
      rear_suspension: "Monoshock, Fully Adjustable",
      front_suspension_travel: "220mm",
      rear_suspension_travel: "220mm",
      front_brake: "Dual 320mm Discs, 4-Piston Calipers",
      rear_brake: "260mm Disc, Single-Piston Caliper",
      abs: "Dual-Channel ABS",
      front_tire: "90/90-21",
      rear_tire: "150/70-18",
      front_wheel: "21\" Spoke Wheel",
      rear_wheel: "18\" Spoke Wheel"
    }

    {:ok, _chassis} =
      %ChassisSpec{}
      |> ChassisSpec.changeset(Map.merge(chassis_defaults, chassis_attrs))
      |> Repo.insert()

    # Create dimension
    dimension_defaults = %{
      bike_id: bike.id,
      seat_height: "910mm",
      ground_clearance: "280mm",
      wheelbase: "1525mm",
      fuel_capacity: "21L",
      wet_weight: "225kg"
    }

    {:ok, _dimension} =
      %Dimension{}
      |> Dimension.changeset(Map.merge(dimension_defaults, dimension_attrs))
      |> Repo.insert()

    # Create default features if none specified
    if Enum.empty?(features_attrs) do
      default_features = [
        %{bike_id: bike.id, name: "TFT Display", position: 0},
        %{bike_id: bike.id, name: "LED Lighting", position: 1}
      ]

      for feature_attrs <- default_features do
        {:ok, _} =
          %BikeFeature{}
          |> BikeFeature.changeset(feature_attrs)
          |> Repo.insert()
      end
    else
      for {feature_attrs, idx} <- Enum.with_index(features_attrs) do
        {:ok, _} =
          %BikeFeature{}
          |> BikeFeature.changeset(Map.merge(%{bike_id: bike.id, position: idx}, feature_attrs))
          |> Repo.insert()
      end
    end

    # Create default images if none specified
    if Enum.empty?(images_attrs) do
      default_images = [
        %{bike_id: bike.id, url: "https://example.com/img1.jpg", position: 0},
        %{bike_id: bike.id, url: "https://example.com/img2.jpg", position: 1}
      ]

      for image_attrs <- default_images do
        {:ok, _} =
          %Image{}
          |> Image.changeset(image_attrs)
          |> Repo.insert()
      end
    else
      for {image_attrs, idx} <- Enum.with_index(images_attrs) do
        {:ok, _} =
          %Image{}
          |> Image.changeset(Map.merge(%{bike_id: bike.id, position: idx}, image_attrs))
          |> Repo.insert()
      end
    end

    # Create default descriptions if none specified
    if Enum.empty?(descriptions_attrs) do
      default_descriptions = [
        %{
          bike_id: bike.id,
          kind: :marketing,
          body: "Marketing description for test bike",
          position: 0
        },
        %{bike_id: bike.id, kind: :technical, body: "Technical specs", position: 1}
      ]

      for desc_attrs <- default_descriptions do
        {:ok, _} =
          %Description{}
          |> Description.changeset(desc_attrs)
          |> Repo.insert()
      end
    else
      for {desc_attrs, idx} <- Enum.with_index(descriptions_attrs) do
        {:ok, _} =
          %Description{}
          |> Description.changeset(Map.merge(%{bike_id: bike.id, position: idx}, desc_attrs))
          |> Repo.insert()
      end
    end

    # Preload all associations like Bikes.get_bike!/1 does
    Kove.Bikes.get_bike!(bike.id)
  end
end
