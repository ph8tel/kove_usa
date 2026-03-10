defmodule Kove.UserBikes.UserBikeModTest do
  use Kove.DataCase, async: true

  alias Kove.UserBikes.UserBikeMod

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset =
        UserBikeMod.changeset(%UserBikeMod{}, %{
          mod_type: :exhaust,
          description: "Full titanium system"
        })

      assert changeset.valid?
    end

    test "valid changeset with all fields" do
      changeset =
        UserBikeMod.changeset(%UserBikeMod{}, %{
          mod_type: :suspension,
          description: "Re-valved forks with heavier springs",
          brand: "Cogent Dynamics",
          cost_cents: 89900,
          installed_at: ~D[2026-01-15],
          rating: 5,
          position: 0
        })

      assert changeset.valid?
    end

    test "requires mod_type" do
      changeset = UserBikeMod.changeset(%UserBikeMod{}, %{description: "Something"})
      assert %{mod_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires description" do
      changeset = UserBikeMod.changeset(%UserBikeMod{}, %{mod_type: :exhaust})
      assert %{description: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates description minimum length" do
      changeset =
        UserBikeMod.changeset(%UserBikeMod{}, %{mod_type: :exhaust, description: "ab"})

      assert %{description: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "validates description maximum length" do
      long_desc = String.duplicate("a", 501)

      changeset =
        UserBikeMod.changeset(%UserBikeMod{}, %{mod_type: :exhaust, description: long_desc})

      assert %{description: ["should be at most 500 character(s)"]} = errors_on(changeset)
    end

    test "validates brand maximum length" do
      changeset =
        UserBikeMod.changeset(%UserBikeMod{}, %{
          mod_type: :exhaust,
          description: "Full system",
          brand: String.duplicate("a", 101)
        })

      assert %{brand: ["should be at most 100 character(s)"]} = errors_on(changeset)
    end

    test "validates cost_cents is non-negative" do
      changeset =
        UserBikeMod.changeset(%UserBikeMod{}, %{
          mod_type: :exhaust,
          description: "Full system",
          cost_cents: -100
        })

      assert %{cost_cents: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "validates rating between 1 and 5" do
      changeset_low =
        UserBikeMod.changeset(%UserBikeMod{}, %{
          mod_type: :exhaust,
          description: "Full system",
          rating: 0
        })

      assert %{rating: ["must be greater than or equal to 1"]} = errors_on(changeset_low)

      changeset_high =
        UserBikeMod.changeset(%UserBikeMod{}, %{
          mod_type: :exhaust,
          description: "Full system",
          rating: 6
        })

      assert %{rating: ["must be less than or equal to 5"]} = errors_on(changeset_high)
    end

    test "validates mod_type is one of the allowed values" do
      changeset =
        UserBikeMod.changeset(%UserBikeMod{}, %{
          mod_type: :invalid_type,
          description: "Something"
        })

      refute changeset.valid?
    end
  end

  describe "mod_types/0" do
    test "returns all 11 mod types" do
      types = UserBikeMod.mod_types()
      assert length(types) == 11
      assert :exhaust in types
      assert :gearing in types
      assert :suspension in types
      assert :clutch in types
      assert :engine in types
      assert :electronics in types
      assert :intake in types
      assert :controls in types
      assert :tires in types
      assert :protection in types
      assert :lighting in types
    end
  end

  describe "mod_type_label/1" do
    test "returns human labels for all types" do
      assert UserBikeMod.mod_type_label(:exhaust) == "Exhaust"
      assert UserBikeMod.mod_type_label(:gearing) == "Gearing"
      assert UserBikeMod.mod_type_label(:suspension) == "Suspension"
      assert UserBikeMod.mod_type_label(:clutch) == "Clutch"
      assert UserBikeMod.mod_type_label(:engine) == "Engine"
      assert UserBikeMod.mod_type_label(:electronics) == "Electronics"
      assert UserBikeMod.mod_type_label(:intake) == "Intake"
      assert UserBikeMod.mod_type_label(:controls) == "Controls"
      assert UserBikeMod.mod_type_label(:tires) == "Tires"
      assert UserBikeMod.mod_type_label(:protection) == "Protection"
      assert UserBikeMod.mod_type_label(:lighting) == "Lighting"
    end
  end
end
