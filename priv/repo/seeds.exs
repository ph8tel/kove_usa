# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Kove.Repo.insert!(%Kove.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Changeset
alias Kove.Repo

# ============================================================================
# SEED DATA FROM bijes.json
# ============================================================================

# Read and parse the bijes.json file
bijes_path =
  [Path.join(__DIR__, "bijes.json"), Path.expand("../../bijes.json", __DIR__)]
  |> Enum.find(&File.exists?/1)

unless bijes_path do
  raise "bijes.json not found (checked priv/repo/bijes.json and project root)"
end

{:ok, json_content} = File.read(bijes_path)
{:ok, bikes_data} = Jason.decode(json_content)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

defmodule SeedHelpers do
  @doc """
  Extract engine platform name from product name.
  Returns {platform_name, variant} tuple.
  """
  def extract_engine_and_variant(product_name) do
    cond do
      String.contains?(product_name, "800X") ->
        if String.contains?(product_name, "Rally") do
          {"800X Rally (799cc DOHC Parallel Twin)", "Rally"}
        else
          {"800X Rally (799cc DOHC Parallel Twin)", "Pro"}
        end

      String.contains?(product_name, "450") and String.contains?(product_name, "MX") ->
        {"MX450 (449cc SOHC Single)", "Standard"}

      String.contains?(product_name, "450") and String.contains?(product_name, "Rally") ->
        if String.contains?(product_name, "Pro Off-Road") do
          {"450 Rally (449cc DOHC Single)", "Pro Off-Road"}
        else
          {"450 Rally (449cc DOHC Single)", "Street Legal"}
        end

      String.contains?(product_name, "MX450") ->
        {"MX450 (449cc SOHC Single)", "Standard"}

      String.contains?(product_name, "MX250") ->
        {"MX250 (249cc DOHC Finger-Follower)", "Standard"}

      true ->
        raise "Unknown product: #{product_name}"
    end
  end

  @doc """
  Extract year from product name.
  """
  def extract_year(product_name) do
    case Regex.run(~r/(\d{4})/, product_name) do
      [_, year_str] -> String.to_integer(year_str)
      _ -> 2026
    end
  end

  @doc """
  Create a URL-friendly slug from product name.
  """
  def create_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  @doc """
  Determine bike status based on product status field.
  """
  def determine_status(status_str) do
    cond do
      String.contains?(status_str, "Street Legal") -> "street_legal"
      String.contains?(status_str, "Competition") -> "competition"
      true -> "competition"
    end
  end

  @doc """
  Determine bike category based on product name.
  """
  def determine_category(product_name) do
    cond do
      String.contains?(product_name, "800X") -> "adv"
      String.contains?(product_name, "450") and String.contains?(product_name, "MX") -> "mx"
      String.contains?(product_name, "450") and String.contains?(product_name, "Rally") -> "rally"
      String.contains?(product_name, "MX450") -> "mx"
      String.contains?(product_name, "MX250") -> "mx"
      true -> "adv"
    end
  end

  @doc """
  Parse MSRP string to cents.
  Example: "$12,999" -> 1299900
  """
  def parse_msrp(msrp_str) when is_binary(msrp_str) do
    msrp_str
    |> String.replace("$", "")
    |> String.replace(",", "")
    |> String.to_integer()
    |> Kernel.*(100)
  end

  def parse_msrp(nil), do: nil

  @doc """
  Parse weight value. Supports "364 lbs", "364 lbs curb", etc.
  Returns {weight_string, weight_type}
  """
  def parse_weight(weight_str) when is_binary(weight_str) do
    weight_str = String.trim(weight_str)

    weight_type =
      cond do
        String.contains?(weight_str, "curb") -> "curb"
        String.contains?(weight_str, "dry") -> "dry"
        true -> "dry"
      end

    {weight_str, weight_type}
  end

  def parse_weight(nil), do: {nil, nil}

  @doc """
  Normalize chassis field names (abs vs abs_system).
  """
  def normalize_abs_field(chassis) do
    case chassis do
      %{"abs" => value} -> Map.put(chassis, "abs_system", value) |> Map.delete("abs")
      _ -> chassis
    end
  end

  @doc """
  Normalize suspension travel. If only suspension_travel exists,
  copy to both front_travel and rear_travel.
  """
  def normalize_suspension_travel(chassis) do
    case {chassis["suspension_travel"], chassis["front_travel"], chassis["rear_travel"]} do
      {travel, nil, nil} when not is_nil(travel) ->
        chassis
        |> Map.put("front_travel", travel)
        |> Map.put("rear_travel", travel)

      _ ->
        chassis
    end
  end

  @doc """
  Call Groq embeddings API for text.
  Returns embedding vector or nil on failure.
  """
  def get_embedding(text) do
    api_key = Application.get_env(:kove, :groq_api_key)

    if is_nil(api_key) do
      IO.warn(
        "⚠️  GROQ_API_KEY not set - skipping embeddings for: #{String.slice(text, 0..50)}..."
      )

      nil
    else
      try do
        # Try with text-embedding-3-small first (OpenAI compatibility)
        case call_groq_api(text, api_key, "text-embedding-3-small") do
          {:ok, embedding} ->
            embedding

          {:error, _} ->
            # Fallback to nomic-embed-text if OpenAI model not supported
            case call_groq_api(text, api_key, "nomic-embed-text") do
              {:ok, embedding} ->
                embedding

              {:error, reason} ->
                IO.warn("Failed to get embedding: #{reason}")
                nil
            end
        end
      rescue
        e ->
          IO.warn("Error getting embedding: #{inspect(e)}")
          nil
      end
    end
  end

  @doc """
  Call Groq embeddings API with specified model.
  """
  defp call_groq_api(text, api_key, model) do
    url = "https://api.groq.com/openai/v1/embeddings"

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        "model" => model,
        "input" => text
      })

    case Req.post(url, headers: headers, body: body) do
      {:ok, response} ->
        case Jason.decode(response.body) do
          {:ok, %{"data" => [%{"embedding" => embedding} | _]}} ->
            {:ok, embedding}

          {:ok, %{"error" => %{"message" => msg}}} ->
            {:error, msg}

          {:ok, data} ->
            {:error, "Unexpected response: #{inspect(data)}"}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end

# ============================================================================
# CLEAN EXISTING DATA (makes seeds idempotent / re-runnable)
# ============================================================================

IO.puts("Clearing existing seed data...")

Repo.delete_all(Kove.Orders.Order)
Repo.delete_all(Kove.Descriptions.Description)
Repo.delete_all(Kove.Images.Image)
Repo.delete_all(Kove.BikeFeatures.BikeFeature)
Repo.delete_all(Kove.Dimensions.Dimension)
Repo.delete_all(Kove.ChassisSpecs.ChassisSpec)
Repo.delete_all(Kove.Bikes.Bike)
Repo.delete_all(Kove.Engines.Engine)

IO.puts("Existing data cleared.")

# ============================================================================
# CREATE ENGINE PLATFORMS
# ============================================================================

IO.puts("Creating engine platforms...")

# 1. 799cc DOHC Parallel Twin (for 800X Rally and 800X Pro)
engine_800x =
  Repo.insert!(
    Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, %{
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
      max_torque: nil
    })
  )

# 2. 449cc DOHC Single (for 450 Rally Pro and 450 Rally Street Legal)
engine_450 =
  Repo.insert!(
    Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, %{
      platform_name: "450 Rally (449cc DOHC Single)",
      engine_type: "Single Cylinder, DOHC",
      displacement: "449cc",
      bore_x_stroke: "94.5mm x 64mm",
      cooling: "Liquid-Cooled with External Oil Cooler & Dual Fans",
      compression_ratio: nil,
      fuel_system: "Bosch EFI / ECU",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
      starter: "Electric",
      max_power: nil,
      max_torque: nil
    })
  )

# 3. 449cc SOHC Single (for MX450)
engine_mx450 =
  Repo.insert!(
    Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, %{
      platform_name: "MX450 (449cc SOHC Single)",
      engine_type: "Single Cylinder, SOHC",
      displacement: "449.9cc",
      bore_x_stroke: "96mm x 62.15mm",
      cooling: "Liquid-Cooled",
      compression_ratio: nil,
      fuel_system: "Bosch EFI",
      transmission: "5-Speed",
      clutch: "Oil Bath, Multi-Disc, Hydraulic-Actuated",
      starter: "Electric",
      max_power: "52 HP @ 9500rpm",
      max_torque: "32 ft-lbs @ 7500rpm"
    })
  )

# 4. 249cc DOHC Finger-Follower (for MX250)
engine_mx250 =
  Repo.insert!(
    Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, %{
      platform_name: "MX250 (249cc DOHC Finger-Follower)",
      engine_type: "Single Cylinder, DOHC (Finger-Follower)",
      displacement: "249cc",
      bore_x_stroke: "79mm x 51mm",
      cooling: "Liquid-Cooled",
      compression_ratio: "14:1",
      fuel_system: "Bosch EFI",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc, Cable-Actuated",
      starter: "Electric",
      max_power: "40.2 HP @ 12000rpm",
      max_torque: "19.9 ft-lbs @ 7000rpm"
    })
  )

IO.puts("✓ Created 4 engine platforms")

# ============================================================================
# CREATE BIKES AND ASSOCIATED DATA
# ============================================================================

IO.puts("Creating bikes and associated data...")

Enum.each(bikes_data, fn product ->
  product_name = product["product"]
  {platform_name, variant} = SeedHelpers.extract_engine_and_variant(product_name)
  year = SeedHelpers.extract_year(product_name)
  slug = SeedHelpers.create_slug(product_name)
  status = SeedHelpers.determine_status(product["status"])
  category = SeedHelpers.determine_category(product_name)
  msrp_cents = SeedHelpers.parse_msrp(product["msrp"])

  # Determine engine based on platform
  engine =
    cond do
      String.contains?(platform_name, "800X") -> engine_800x
      String.contains?(platform_name, "450 Rally") -> engine_450
      String.contains?(platform_name, "MX450") -> engine_mx450
      String.contains?(platform_name, "MX250") -> engine_mx250
      true -> engine_800x
    end

  # Get first image URL for hero image
  images = product["images"] || []
  hero_image_url = if Enum.any?(images), do: List.first(images)["url"], else: nil

  # Prepare bike attributes
  bike_attrs = %{
    engine_id: engine.id,
    name: product_name,
    year: year,
    variant: variant,
    slug: slug,
    status: status,
    category: category,
    msrp_cents: msrp_cents,
    hero_image_url: hero_image_url
  }

  # Add overrides only for 450 Rally Pro
  bike_attrs =
    if String.contains?(product_name, "450 Rally Pro Off-Road") do
      bike_attrs
      |> Map.put(:exhaust_override, "Full Titanium Closed-Course System")
      |> Map.put(:sprocket_override, "51-tooth Rear")
      |> Map.put(:ecu_override, "Race-tuned ECU")
    else
      bike_attrs
    end

  # Insert the bike
  bike =
    Repo.insert!(Kove.Bikes.Bike.changeset(%Kove.Bikes.Bike{}, bike_attrs))

  IO.puts("  ✓ #{product_name}")

  # ========================================================================
  # CREATE CHASSIS SPECS
  # ========================================================================

  specs = product["specifications"]
  chassis = specs["chassis"] || %{}

  # Normalize chassis fields
  chassis = SeedHelpers.normalize_abs_field(chassis)
  chassis = SeedHelpers.normalize_suspension_travel(chassis)

  chassis_attrs = %{
    bike_id: bike.id,
    frame_type: chassis["frame_type"],
    front_suspension: chassis["front_suspension"],
    front_travel: chassis["front_travel"],
    rear_suspension: chassis["rear_suspension"],
    rear_travel: chassis["rear_travel"],
    front_brake: chassis["front_brake"],
    rear_brake: chassis["rear_brake"],
    abs_system: chassis["abs_system"],
    wheels: chassis["wheels"],
    tires: chassis["tires"],
    steering_angle: chassis["steering_angle"],
    rake_angle: chassis["rake_angle"],
    triple_clamp: chassis["triple_clamp"]
  }

  Repo.insert!(
    Kove.ChassisSpecs.ChassisSpec.changeset(%Kove.ChassisSpecs.ChassisSpec{}, chassis_attrs)
  )

  # ========================================================================
  # CREATE DIMENSIONS
  # ========================================================================

  dimensions_data = specs["dimensions"] || %{}

  {weight, weight_type} =
    SeedHelpers.parse_weight(dimensions_data["dry_weight"] || dimensions_data["curb_weight"])

  dimensions_attrs = %{
    bike_id: bike.id,
    weight: weight,
    weight_type: weight_type,
    fuel_capacity: dimensions_data["fuel_capacity"],
    estimated_range: dimensions_data["estimated_range"],
    overall_size: dimensions_data["overall_size_lxwxh"],
    wheelbase: dimensions_data["wheelbase"],
    seat_height: dimensions_data["seat_height"],
    ground_clearance: dimensions_data["ground_clearance"]
  }

  Repo.insert!(
    Kove.Dimensions.Dimension.changeset(%Kove.Dimensions.Dimension{}, dimensions_attrs)
  )

  # ========================================================================
  # CREATE BIKE FEATURES
  # ========================================================================

  features_list = chassis["features"] || chassis["other_features"] || []

  features_list
  |> Enum.with_index(1)
  |> Enum.each(fn {feature_name, position} ->
    feature_attrs = %{
      bike_id: bike.id,
      name: feature_name,
      position: position
    }

    Repo.insert!(
      Kove.BikeFeatures.BikeFeature.changeset(%Kove.BikeFeatures.BikeFeature{}, feature_attrs)
    )
  end)

  # ========================================================================
  # CREATE IMAGES
  # ========================================================================

  images
  |> Enum.with_index(1)
  |> Enum.each(fn {image, position} ->
    image_attrs = %{
      bike_id: bike.id,
      alt: image["alt"],
      url: image["url"],
      position: position,
      is_hero: position == 1
    }

    Repo.insert!(Kove.Images.Image.changeset(%Kove.Images.Image{}, image_attrs))
  end)

  # ========================================================================
  # CREATE DESCRIPTIONS WITH EMBEDDINGS
  # ========================================================================

  marketing_text = product["marketing_text"] || []

  marketing_text
  |> Enum.with_index(1)
  |> Enum.each(fn {paragraph, position} ->
    # Get embedding from Groq API
    embedding = SeedHelpers.get_embedding(paragraph)

    # Add 100ms delay between API calls to avoid throttling
    Process.sleep(100)

    description_attrs = %{
      bike_id: bike.id,
      kind: "marketing",
      body: paragraph,
      position: position,
      embedding: embedding
    }

    Repo.insert!(
      Kove.Descriptions.Description.changeset(%Kove.Descriptions.Description{}, description_attrs)
    )
  end)
end)

IO.puts("✓ Successfully seeded all bikes and related data")

# ============================================================================
# CREATE PART KITS (Oil Change Kits)
# ============================================================================

IO.puts("Creating oil change kits...")

alias Kove.Parts.PartKit
alias Kove.Parts.PartKitCompatibility

oil_change_kits = [
  %{
    sku: "OIL-KIT-800X",
    name: "800X Oil Change Kit",
    description:
      "Complete oil change kit for the 800X twin — includes 3.5L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
    price_cents: 6499,
    engine: engine_800x
  },
  %{
    sku: "OIL-KIT-450R",
    name: "450 Rally Oil Change Kit",
    description:
      "Complete oil change kit for the 450 Rally — includes 1.6L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
    price_cents: 4299,
    engine: engine_450
  },
  %{
    sku: "OIL-KIT-MX450",
    name: "MX450 Oil Change Kit",
    description:
      "Complete oil change kit for the MX450 — includes 1.4L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
    price_cents: 3999,
    engine: engine_mx450
  },
  %{
    sku: "OIL-KIT-MX250",
    name: "MX250 Oil Change Kit",
    description:
      "Complete oil change kit for the MX250 — includes 1.1L Motul 7100 10W-50 synthetic, OEM oil filter, crush washer, and drain plug O-ring.",
    price_cents: 3499,
    engine: engine_mx250
  }
]

Enum.each(oil_change_kits, fn kit_data ->
  {:ok, kit} =
    %PartKit{}
    |> PartKit.changeset(%{
      sku: kit_data.sku,
      name: kit_data.name,
      description: kit_data.description,
      price_cents: kit_data.price_cents
    })
    |> Repo.insert()

  %PartKitCompatibility{}
  |> PartKitCompatibility.changeset(%{part_kit_id: kit.id, engine_id: kit_data.engine.id})
  |> Repo.insert!()
end)

IO.puts("✓ Created 4 oil change kits")

IO.puts("")
IO.puts("Summary:")
IO.puts("  - 4 engine platforms created")
IO.puts("  - 5 bikes created")
IO.puts("  - Chassis specs, dimensions, features, images, and descriptions created")
IO.puts("  - 4 oil change kits created (one per engine platform)")
IO.puts("")
IO.puts("Database seeding complete!")
