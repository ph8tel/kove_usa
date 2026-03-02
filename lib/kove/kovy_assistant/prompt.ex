defmodule Kove.KovyAssistant.Prompt do
  @moduledoc """
  Builds structured system prompts for Kovy, the Kove Moto USA bike assistant.
  Serialises all available bike data (specs, descriptions, features) into
  context the LLM can ground its answers on.
  """

  alias Kove.Bikes

  @doc """
  Returns the full system‑prompt string for a conversation about `bike`.
  """
  def build_system_prompt(bike) do
    """
    You are Kovy, the Kove Moto USA bike assistant. You're knowledgeable, \
    technical, and honest — like a well‑informed friend at the dealership who \
    also happens to be a mechanic and rally rider.

    PERSONALITY & TONE:
    - Technical and straightforward — never salesy or hype‑driven
    - Reference real‑world riding scenarios and practical considerations
    - You know the ADV / rally / MX market well, especially KTM, Husqvarna, GasGas, and Honda
    - When comparing, be factual: acknowledge where competitors are strong and where Kove stands out
    - Address Chinese‑manufacturing quality concerns directly and honestly
    - Enthusiastic about Kove's Dakar heritage and continuous engineering improvements
    - Kove is pronounced like "cove" (as in a sheltered bay)

    CURRENT BIKE CONTEXT:
    #{bike_context(bike)}

    RULES:
    - Ground your answers in the specs and descriptions above — do not invent data
    - If you lack info on something, say so honestly
    - Keep responses concise: 2‑4 short paragraphs max
    - Use both metric and imperial when citing measurements
    - For maintenance: be realistic about intervals, parts availability, and dealer network
    - For upgrades: suggest what riders actually do (protection, ergonomics, suspension tuning)
    - For comparisons: use specific numbers (displacement, weight, travel, price)
    - Never claim Kove is "better" without backing it up with specs
    """
    |> String.trim()
  end

  @doc """
  Returns the system‑prompt string for a catalog‑wide conversation.

  Includes a compact one‑line summary for every bike, plus full detailed context
  only for bikes that match keywords in `user_message` (pseudo‑RAG).
  If no bikes match (e.g. general questions), only the catalog summary is included.
  """
  def build_catalog_system_prompt(bikes, user_message) do
    matched = relevant_bikes(bikes, user_message)

    detailed_section =
      case matched do
        [] ->
          ""

        _ ->
          details =
            matched
            |> Enum.map(&bike_context/1)
            |> Enum.join("\n\n---\n\n")

          "\nDETAILED SPECS FOR RELEVANT BIKES:\n#{details}"
      end

    """
    You are Kovy, the Kove Moto USA catalog assistant. You're knowledgeable, \
    technical, and honest — like a well‑informed friend at the dealership who \
    also happens to be a mechanic and rally rider.

    PERSONALITY & TONE:
    - Technical and straightforward — never salesy or hype‑driven
    - Reference real‑world riding scenarios and practical considerations
    - You know the ADV / rally / MX market well, especially KTM, Husqvarna, GasGas, and Honda
    - When comparing, be factual: acknowledge where competitors are strong and where Kove stands out
    - Address Chinese‑manufacturing quality concerns directly and honestly
    - Enthusiastic about Kove's Dakar heritage and continuous engineering improvements
    - Kove is pronounced like "cove" (as in a sheltered bay)

    You have access to the FULL Kove Moto USA catalog. Here is every model:

    CATALOG SUMMARY:
    #{catalog_summary(bikes)}
    #{detailed_section}

    RULES:
    - Ground your answers in the specs above — do not invent data
    - If you lack info on something, say so honestly
    - Keep responses concise: 2‑4 short paragraphs max
    - Use both metric and imperial when citing measurements
    - For comparisons: use specific numbers (displacement, weight, travel, price)
    - Never claim Kove is "better" without backing it up with specs
    - When the user wants help choosing a bike, ask about their riding experience, \
    preferred terrain, intended use (commute, touring, off‑road, track), and budget \
    before recommending — guide them through it conversationally like a rider‑type survey
    """
    |> String.trim()
  end

  @doc """
  Returns the subset of `bikes` whose names, slugs, or categories match
  keywords found in `user_message`. Case‑insensitive.

  This is a lightweight pseudo‑RAG: only bikes the user appears to be asking
  about get their full specs serialised into the prompt.
  """
  def relevant_bikes(bikes, user_message) do
    query = String.downcase(user_message)

    Enum.filter(bikes, fn bike ->
      tokens = bike_search_tokens(bike)
      Enum.any?(tokens, fn token -> String.contains?(query, token) end)
    end)
  end

  # ── Private helpers ────────────────────────────────────────────────────

  defp catalog_summary(bikes) do
    bikes
    |> Enum.map(fn bike ->
      displacement =
        case bike.engine do
          nil -> ""
          %Ecto.Association.NotLoaded{} -> ""
          engine -> engine.displacement || ""
        end

      "- #{bike.name} | #{Bikes.category_label(bike.category)} | #{displacement} | #{Bikes.format_msrp(bike.msrp_cents)}"
    end)
    |> Enum.join("\n")
  end

  defp bike_search_tokens(bike) do
    # Build a list of lowercase tokens from bike attributes that users might mention
    name_tokens =
      bike.name
      |> String.downcase()
      |> String.split(~r/[\s\-]+/, trim: true)
      |> Enum.reject(&(String.length(&1) < 3))

    slug_tokens =
      bike.slug
      |> String.downcase()
      |> String.split(~r/[\s\-]+/, trim: true)
      |> Enum.reject(&(String.length(&1) < 3))

    category_tokens =
      case bike.category do
        :adv -> ["adventure", "adv"]
        :rally -> ["rally"]
        :mx -> ["motocross", "mx"]
        _ -> []
      end

    variant_tokens =
      if bike.variant do
        [String.downcase(bike.variant)]
      else
        []
      end

    (name_tokens ++ slug_tokens ++ category_tokens ++ variant_tokens)
    |> Enum.uniq()
  end

  defp bike_context(bike) do
    [
      bike_header(bike),
      engine_section(bike.engine),
      chassis_section(bike.chassis_spec),
      dimension_section(bike.dimension),
      features_section(bike.bike_features),
      descriptions_section(bike.descriptions)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  # ── Header ──

  defp bike_header(bike) do
    lines =
      [
        "Model: #{bike.name}",
        "Year: #{bike.year}",
        "Category: #{Bikes.category_label(bike.category)}",
        "Status: #{Bikes.status_label(bike.status)}",
        "MSRP: #{Bikes.format_msrp(bike.msrp_cents)}",
        if(bike.variant, do: "Variant: #{bike.variant}"),
        if(bike.exhaust_override, do: "Exhaust: #{bike.exhaust_override}"),
        if(bike.sprocket_override, do: "Sprocket: #{bike.sprocket_override}"),
        if(bike.ecu_override, do: "ECU: #{bike.ecu_override}")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    "=== BIKE ===\n#{lines}"
  end

  # ── Engine ──

  defp engine_section(nil), do: nil
  defp engine_section(%Ecto.Association.NotLoaded{}), do: nil

  defp engine_section(engine) do
    fields = [
      {"Platform", engine.platform_name},
      {"Type", engine.engine_type},
      {"Displacement", engine.displacement},
      {"Bore × Stroke", engine.bore_x_stroke},
      {"Cooling", engine.cooling},
      {"Compression Ratio", engine.compression_ratio},
      {"Fuel System", engine.fuel_system},
      {"Transmission", engine.transmission},
      {"Clutch", engine.clutch},
      {"Starter", engine.starter},
      {"Max Power", engine.max_power},
      {"Max Torque", engine.max_torque}
    ]

    format_spec_section("ENGINE", fields)
  end

  # ── Chassis ──

  defp chassis_section(nil), do: nil
  defp chassis_section(%Ecto.Association.NotLoaded{}), do: nil

  defp chassis_section(chassis) do
    fields = [
      {"Frame", chassis.frame_type},
      {"Front Suspension", chassis.front_suspension},
      {"Front Travel", chassis.front_travel},
      {"Rear Suspension", chassis.rear_suspension},
      {"Rear Travel", chassis.rear_travel},
      {"Front Brake", chassis.front_brake},
      {"Rear Brake", chassis.rear_brake},
      {"ABS", chassis.abs_system},
      {"Wheels", chassis.wheels},
      {"Tires", chassis.tires},
      {"Steering Angle", chassis.steering_angle},
      {"Rake Angle", chassis.rake_angle},
      {"Triple Clamp", chassis.triple_clamp}
    ]

    format_spec_section("CHASSIS", fields)
  end

  # ── Dimensions ──

  defp dimension_section(nil), do: nil
  defp dimension_section(%Ecto.Association.NotLoaded{}), do: nil

  defp dimension_section(dim) do
    weight_label = if dim.weight_type, do: "Weight (#{dim.weight_type})", else: "Weight"

    fields = [
      {weight_label, dim.weight},
      {"Fuel Capacity", dim.fuel_capacity},
      {"Estimated Range", dim.estimated_range},
      {"Overall Size", dim.overall_size},
      {"Wheelbase", dim.wheelbase},
      {"Seat Height", dim.seat_height},
      {"Ground Clearance", dim.ground_clearance}
    ]

    format_spec_section("DIMENSIONS", fields)
  end

  # ── Features ──

  defp features_section(nil), do: nil
  defp features_section(%Ecto.Association.NotLoaded{}), do: nil
  defp features_section([]), do: nil

  defp features_section(features) when is_list(features) do
    items =
      features
      |> Enum.sort_by(& &1.position)
      |> Enum.map(&"- #{&1.name}")
      |> Enum.join("\n")

    "=== KEY FEATURES ===\n#{items}"
  end

  # ── Descriptions ──

  defp descriptions_section(nil), do: nil
  defp descriptions_section(%Ecto.Association.NotLoaded{}), do: nil
  defp descriptions_section([]), do: nil

  defp descriptions_section(descriptions) when is_list(descriptions) do
    text =
      descriptions
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.body)
      |> Enum.join("\n\n")

    "=== MARKETING DESCRIPTIONS ===\n#{text}"
  end

  # ── Formatting ──

  defp format_spec_section(title, fields) do
    lines =
      fields
      |> Enum.reject(fn {_, v} -> is_nil(v) || v == "" end)
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
      |> Enum.join("\n")

    if lines == "", do: nil, else: "=== #{title} ===\n#{lines}"
  end
end
