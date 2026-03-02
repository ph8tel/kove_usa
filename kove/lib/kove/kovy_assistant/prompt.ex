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

  # ── Private helpers ────────────────────────────────────────────────────

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
