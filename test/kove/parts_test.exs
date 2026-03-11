defmodule Kove.PartsTest do
  use Kove.DataCase

  alias Kove.Parts
  import Kove.BikesFixtures
  import Kove.PartsFixtures

  setup do
    engine = engine_fixture()
    bike = bike_fixture(engine)
    {:ok, engine: engine, bike: bike}
  end

  describe "list_kits_for_bike/1" do
    test "returns kits compatible with the bike's engine", %{engine: engine, bike: bike} do
      {kit, _compat} = part_kit_with_engine_fixture(engine, %{name: "Oil Kit"})

      result = Parts.list_kits_for_bike(bike)
      assert length(result) == 1
      assert hd(result).id == kit.id
    end

    test "does not return kits for other engines", %{bike: bike} do
      other_engine =
        engine_fixture(%{
          platform_name: "MX250 (249cc DOHC Finger-Follower)",
          displacement: "249cc"
        })

      {_kit, _compat} = part_kit_with_engine_fixture(other_engine, %{name: "MX250 Kit"})

      result = Parts.list_kits_for_bike(bike)
      assert result == []
    end

    test "does not return inactive kits", %{engine: engine, bike: bike} do
      {kit, _compat} = part_kit_with_engine_fixture(engine, %{name: "Inactive Kit"})
      kit |> Ecto.Changeset.change(active: false) |> Kove.Repo.update!()

      result = Parts.list_kits_for_bike(bike)
      assert result == []
    end

    test "returns empty list for nil bike" do
      assert Parts.list_kits_for_bike(nil) == []
    end
  end

  describe "oil_change_kit_for_bike/1" do
    test "returns oil change kit for the bike's engine", %{engine: engine, bike: bike} do
      {kit, _compat} =
        part_kit_with_engine_fixture(engine, %{name: "800X Oil Change Kit"})

      result = Parts.oil_change_kit_for_bike(bike)
      assert result.id == kit.id
    end

    test "does not return non-oil-change kits", %{engine: engine, bike: bike} do
      {_kit, _compat} =
        part_kit_with_engine_fixture(engine, %{name: "Air Filter Kit"})

      result = Parts.oil_change_kit_for_bike(bike)
      assert result == nil
    end

    test "returns nil for nil bike" do
      assert Parts.oil_change_kit_for_bike(nil) == nil
    end
  end

  describe "list_kits/0" do
    test "returns all active kits" do
      part_kit_fixture(%{name: "Kit A"})
      part_kit_fixture(%{name: "Kit B"})

      result = Parts.list_kits()
      assert length(result) == 2
    end

    test "does not return inactive kits" do
      kit = part_kit_fixture(%{name: "Inactive"})
      kit |> Ecto.Changeset.change(active: false) |> Kove.Repo.update!()

      result = Parts.list_kits()
      assert result == []
    end
  end

  describe "get_kit!/1" do
    test "returns the kit with the given id" do
      kit = part_kit_fixture()
      assert Parts.get_kit!(kit.id).id == kit.id
    end

    test "raises on non-existent id" do
      assert_raise Ecto.NoResultsError, fn -> Parts.get_kit!(0) end
    end
  end

  describe "create_kit/1" do
    test "creates a kit with valid attrs" do
      attrs = %{sku: "NEW-KIT", name: "New Kit", price_cents: 1000}
      assert {:ok, kit} = Parts.create_kit(attrs)
      assert kit.sku == "NEW-KIT"
      assert kit.name == "New Kit"
      assert kit.price_cents == 1000
    end

    test "fails with invalid attrs" do
      assert {:error, _changeset} = Parts.create_kit(%{})
    end
  end

  describe "add_compatibility/2" do
    test "links a kit to an engine", %{engine: engine} do
      kit = part_kit_fixture()
      assert {:ok, compat} = Parts.add_compatibility(kit.id, engine.id)
      assert compat.part_kit_id == kit.id
      assert compat.engine_id == engine.id
    end
  end
end
