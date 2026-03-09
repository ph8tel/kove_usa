defmodule Kove.KovyAssistant.PromptTest do
  use Kove.DataCase, async: true

  alias Kove.KovyAssistant.Prompt

  # ── Helpers ──────────────────────────────────────────────────────────

  defp build_bike(overrides \\ %{}) do
    defaults = %{
      name: "2026 Kove 800X Pro",
      year: 2026,
      variant: "Pro",
      slug: "2026-kove-800x-pro",
      status: :street_legal,
      category: :adv,
      msrp_cents: 1_299_900,
      hero_image_url: "https://example.com/hero.jpg",
      exhaust_override: nil,
      sprocket_override: nil,
      ecu_override: nil,
      engine: build_engine(),
      chassis_spec: build_chassis(),
      dimension: build_dimension(),
      bike_features: build_features(),
      descriptions: build_descriptions()
    }

    struct!(Kove.Bikes.Bike, Map.merge(defaults, overrides))
  end

  defp build_engine do
    %Kove.Engines.Engine{
      platform_name: "800X (799cc DOHC Parallel Twin)",
      engine_type: "Twin Cylinder, DOHC",
      displacement: "799cc",
      bore_x_stroke: "88mm × 65.7mm",
      cooling: "Liquid-Cooled",
      compression_ratio: "11.5:1",
      fuel_system: "Bosch EFI",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc",
      starter: "Electric",
      max_power: "95 HP @ 9,000 rpm",
      max_torque: "87 Nm @ 6,500 rpm"
    }
  end

  defp build_chassis do
    %Kove.ChassisSpecs.ChassisSpec{
      frame_type: "Chromoly Steel Trellis",
      front_suspension: "KYB 48mm Inverted Fork",
      front_travel: "230mm",
      rear_suspension: "KYB Fully Adjustable Shock",
      rear_travel: "220mm",
      front_brake: "320mm Dual Disc, Brembo 4-Piston",
      rear_brake: "260mm Single Disc, Brembo 1-Piston",
      abs_system: "Bosch 9.3 ABS (switchable)",
      wheels: "21\" Front / 18\" Rear, Spoked",
      tires: "90/90-21 / 150/70-18",
      steering_angle: nil,
      rake_angle: nil,
      triple_clamp: nil
    }
  end

  defp build_dimension do
    %Kove.Dimensions.Dimension{
      weight: "228 kg",
      weight_type: "wet",
      fuel_capacity: "21 L",
      estimated_range: "~400 km",
      overall_size: nil,
      wheelbase: "1,560 mm",
      seat_height: "870 mm",
      ground_clearance: "250 mm"
    }
  end

  defp build_features do
    [
      %Kove.BikeFeatures.BikeFeature{name: "Rally Tower with GPS Mount", position: 1},
      %Kove.BikeFeatures.BikeFeature{name: "Handguards with Wind Deflectors", position: 2},
      %Kove.BikeFeatures.BikeFeature{name: "Engine Crash Bars", position: 3}
    ]
  end

  defp build_descriptions do
    [
      %Kove.Descriptions.Description{
        kind: :marketing,
        body: "The 800X Pro is a true adventure machine built for the open road.",
        position: 1
      },
      %Kove.Descriptions.Description{
        kind: :technical,
        body: "Featuring Kove's proven 799cc parallel twin, refined after Dakar testing.",
        position: 2
      }
    ]
  end

  # ── Tests ────────────────────────────────────────────────────────────

  describe "build_system_prompt/1" do
    test "includes Kovy personality and rules" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "You are Kovy"
      assert prompt =~ "Kove Moto USA"
      assert prompt =~ "technical"
      assert prompt =~ "never salesy"
      assert prompt =~ "Dakar"
    end

    test "includes bike header info" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "=== BIKE ==="
      assert prompt =~ "2026 Kove 800X Pro"
      assert prompt =~ "2026"
      assert prompt =~ "Adventure"
      assert prompt =~ "Street Legal"
      assert prompt =~ "$12,999"
    end

    test "includes variant when present" do
      prompt = Prompt.build_system_prompt(build_bike(%{variant: "Rally"}))
      assert prompt =~ "Variant: Rally"
    end

    test "excludes variant when nil" do
      prompt = Prompt.build_system_prompt(build_bike(%{variant: nil}))
      refute prompt =~ "Variant:"
    end

    test "includes engine section" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "=== ENGINE ==="
      assert prompt =~ "799cc"
      assert prompt =~ "Twin Cylinder, DOHC"
      assert prompt =~ "Bosch EFI"
      assert prompt =~ "95 HP"
    end

    test "handles nil engine gracefully" do
      prompt = Prompt.build_system_prompt(build_bike(%{engine: nil}))
      refute prompt =~ "=== ENGINE ==="
    end

    test "handles NotLoaded engine gracefully" do
      prompt = Prompt.build_system_prompt(build_bike(%{engine: %Ecto.Association.NotLoaded{}}))
      refute prompt =~ "=== ENGINE ==="
    end

    test "includes chassis section" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "=== CHASSIS ==="
      assert prompt =~ "Chromoly Steel Trellis"
      assert prompt =~ "KYB 48mm"
      assert prompt =~ "Brembo"
      assert prompt =~ "Bosch 9.3 ABS"
    end

    test "handles nil chassis gracefully" do
      prompt = Prompt.build_system_prompt(build_bike(%{chassis_spec: nil}))
      refute prompt =~ "=== CHASSIS ==="
    end

    test "includes dimensions section" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "=== DIMENSIONS ==="
      assert prompt =~ "228 kg"
      assert prompt =~ "Weight (wet)"
      assert prompt =~ "21 L"
      assert prompt =~ "870 mm"
    end

    test "handles nil dimension gracefully" do
      prompt = Prompt.build_system_prompt(build_bike(%{dimension: nil}))
      refute prompt =~ "=== DIMENSIONS ==="
    end

    test "includes features section sorted by position" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "=== KEY FEATURES ==="
      assert prompt =~ "- Rally Tower with GPS Mount"
      assert prompt =~ "- Engine Crash Bars"
    end

    test "handles empty features list" do
      prompt = Prompt.build_system_prompt(build_bike(%{bike_features: []}))
      refute prompt =~ "=== KEY FEATURES ==="
    end

    test "includes descriptions section" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "=== MARKETING DESCRIPTIONS ==="
      assert prompt =~ "true adventure machine"
      assert prompt =~ "Dakar testing"
    end

    test "handles empty descriptions list" do
      prompt = Prompt.build_system_prompt(build_bike(%{descriptions: []}))
      refute prompt =~ "=== MARKETING DESCRIPTIONS ==="
    end

    test "includes overrides when present" do
      bike =
        build_bike(%{
          exhaust_override: "Akrapovič Full System",
          sprocket_override: "-1/+2",
          ecu_override: "Kove Race ECU Flash"
        })

      prompt = Prompt.build_system_prompt(bike)

      assert prompt =~ "Exhaust: Akrapovič Full System"
      assert prompt =~ "Sprocket: -1/+2"
      assert prompt =~ "ECU: Kove Race ECU Flash"
    end

    test "prompt is a non-empty string" do
      prompt = Prompt.build_system_prompt(build_bike())
      assert is_binary(prompt)
      assert String.length(prompt) > 500
    end

    test "prompt includes rules for grounding answers" do
      prompt = Prompt.build_system_prompt(build_bike())

      assert prompt =~ "Ground your answers"
      assert prompt =~ "do not invent data"
      assert prompt =~ "concise"
    end
  end

  # ── Catalog prompt tests ─────────────────────────────────────────────

  describe "build_catalog_system_prompt/2" do
    test "includes Kovy catalog personality" do
      bikes = [
        build_bike(),
        build_bike(%{name: "2026 Kove 450 Rally", slug: "2026-kove-450-rally", category: :rally})
      ]

      prompt = Prompt.build_catalog_system_prompt(bikes, "hello")

      assert prompt =~ "You are Kovy"
      assert prompt =~ "catalog assistant"
      assert prompt =~ "CATALOG SUMMARY"
    end

    test "always includes a compact summary for every bike" do
      bike_a = build_bike(%{name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})

      bike_b =
        build_bike(%{name: "2026 Kove 450 Rally", slug: "2026-kove-450-rally", category: :rally})

      prompt = Prompt.build_catalog_system_prompt([bike_a, bike_b], "hello")

      assert prompt =~ "2026 Kove 800X Pro"
      assert prompt =~ "2026 Kove 450 Rally"
      assert prompt =~ "CATALOG SUMMARY"
    end

    test "includes detailed specs only for matched bikes" do
      bike_a = build_bike(%{name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})

      bike_b =
        build_bike(%{name: "2026 Kove 450 Rally", slug: "2026-kove-450-rally", category: :rally})

      prompt = Prompt.build_catalog_system_prompt([bike_a, bike_b], "tell me about the 800X")

      assert prompt =~ "DETAILED SPECS FOR RELEVANT BIKES"
      assert prompt =~ "=== BIKE ==="
      assert prompt =~ "2026 Kove 800X Pro"
      # The 450 Rally should NOT have detailed specs
      refute prompt =~ "=== BIKE ===\nModel: 2026 Kove 450 Rally"
    end

    test "includes no detailed section when nothing matches" do
      bike = build_bike()
      prompt = Prompt.build_catalog_system_prompt([bike], "what is the meaning of life?")

      refute prompt =~ "DETAILED SPECS"
      refute prompt =~ "=== BIKE ==="
    end

    test "includes rider-type survey instruction" do
      prompt = Prompt.build_catalog_system_prompt([build_bike()], "help me choose")

      assert prompt =~ "riding experience"
      assert prompt =~ "terrain"
      assert prompt =~ "budget"
    end

    test "uses relevant_bike_ids list when provided, bypassing keyword matching" do
      bike_a =
        build_bike(%{id: 1, name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})

      bike_b =
        build_bike(%{
          id: 2,
          name: "2026 Kove 450 Rally",
          slug: "2026-kove-450-rally",
          category: :rally
        })

      # Pass bike_b's id — even though "800X" appears in the message,
      # the explicit ids list takes priority.
      prompt =
        Prompt.build_catalog_system_prompt(
          [bike_a, bike_b],
          "tell me about the 800X",
          [2]
        )

      assert prompt =~ "DETAILED SPECS FOR RELEVANT BIKES"
      assert prompt =~ "2026 Kove 450 Rally"
      # The 800X should NOT have detailed specs since it wasn't in relevant_ids
      refute prompt =~ "Model: 2026 Kove 800X Pro\n"
    end

    test "falls back to keyword matching when relevant_bike_ids is nil" do
      bike_a =
        build_bike(%{id: 1, name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})

      bike_b =
        build_bike(%{
          id: 2,
          name: "2026 Kove 450 Rally",
          slug: "2026-kove-450-rally",
          category: :rally
        })

      # nil → keyword matching, "800X" should match bike_a
      prompt = Prompt.build_catalog_system_prompt([bike_a, bike_b], "tell me about the 800X", nil)

      assert prompt =~ "2026 Kove 800X Pro"
      assert prompt =~ "DETAILED SPECS FOR RELEVANT BIKES"
    end

    test "falls back to keyword matching when relevant_bike_ids is empty" do
      bike = build_bike(%{id: 1, name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})

      # [] → keyword matching
      prompt = Prompt.build_catalog_system_prompt([bike], "tell me about the 800X", [])

      assert prompt =~ "DETAILED SPECS FOR RELEVANT BIKES"
    end
  end

  describe "relevant_bikes/2" do
    test "matches by bike name fragments" do
      bike_a = build_bike(%{name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})

      bike_b =
        build_bike(%{name: "2026 Kove 450 Rally", slug: "2026-kove-450-rally", category: :rally})

      result = Prompt.relevant_bikes([bike_a, bike_b], "Tell me about the 800X")
      assert length(result) == 1
      assert hd(result).name == "2026 Kove 800X Pro"
    end

    test "matches by category keyword" do
      bike_a =
        build_bike(%{name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro", category: :adv})

      bike_b =
        build_bike(%{name: "2026 Kove 450 Rally", slug: "2026-kove-450-rally", category: :rally})

      result = Prompt.relevant_bikes([bike_a, bike_b], "What rally bikes do you have?")
      assert length(result) == 1
      assert hd(result).name == "2026 Kove 450 Rally"
    end

    test "matches multiple bikes when both are mentioned" do
      bike_a = build_bike(%{name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})

      bike_b =
        build_bike(%{name: "2026 Kove 450 Rally", slug: "2026-kove-450-rally", category: :rally})

      result = Prompt.relevant_bikes([bike_a, bike_b], "Compare the 800X and 450 Rally")
      assert length(result) == 2
    end

    test "returns empty list when nothing matches" do
      bike = build_bike()
      result = Prompt.relevant_bikes([bike], "what is the weather?")
      assert result == []
    end

    test "matching is case-insensitive" do
      bike = build_bike(%{name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro"})
      result = Prompt.relevant_bikes([bike], "TELL ME ABOUT THE 800x")
      assert length(result) == 1
    end

    test "matches by adventure category keyword" do
      bike = build_bike(%{name: "2026 Kove 800X Pro", slug: "2026-kove-800x-pro", category: :adv})
      result = Prompt.relevant_bikes([bike], "What adventure bikes do you sell?")
      assert length(result) == 1
    end

    test "matches by motocross category keyword" do
      bike = build_bike(%{name: "2026 Kove MX 250F", slug: "2026-kove-mx-250f", category: :mx})
      result = Prompt.relevant_bikes([bike], "Do you have any motocross bikes?")
      assert length(result) == 1
    end
  end
end
