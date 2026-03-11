defmodule Kove.Parts.PartKitCompatibilityTest do
  use Kove.DataCase

  alias Kove.Parts.PartKitCompatibility
  import Kove.BikesFixtures
  import Kove.PartsFixtures

  setup do
    engine = engine_fixture()
    kit = part_kit_fixture()
    {:ok, engine: engine, kit: kit}
  end

  describe "changeset/2" do
    test "valid changeset", %{engine: engine, kit: kit} do
      attrs = %{part_kit_id: kit.id, engine_id: engine.id}
      changeset = PartKitCompatibility.changeset(%PartKitCompatibility{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing part_kit_id", %{engine: engine} do
      attrs = %{engine_id: engine.id}
      changeset = PartKitCompatibility.changeset(%PartKitCompatibility{}, attrs)
      refute changeset.valid?
      assert :part_kit_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing engine_id", %{kit: kit} do
      attrs = %{part_kit_id: kit.id}
      changeset = PartKitCompatibility.changeset(%PartKitCompatibility{}, attrs)
      refute changeset.valid?
      assert :engine_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "enforces unique constraint on [part_kit_id, engine_id]", %{engine: engine, kit: kit} do
      attrs = %{part_kit_id: kit.id, engine_id: engine.id}

      {:ok, _} =
        %PartKitCompatibility{}
        |> PartKitCompatibility.changeset(attrs)
        |> Kove.Repo.insert()

      assert {:error, changeset} =
               %PartKitCompatibility{}
               |> PartKitCompatibility.changeset(attrs)
               |> Kove.Repo.insert()

      assert :part_kit_id in Enum.map(changeset.errors, fn {field, _} -> field end)
    end
  end
end
