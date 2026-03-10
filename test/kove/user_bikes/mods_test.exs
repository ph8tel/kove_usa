defmodule Kove.UserBikes.ModsTest do
  use Kove.DataCase, async: true

  alias Kove.UserBikes
  alias Kove.UserBikes.UserBikeMod

  import Kove.AccountsFixtures
  import Kove.BikesFixtures

  setup do
    user = user_fixture()
    bike = bike_fixture()
    {:ok, user_bike} = UserBikes.create_user_bike(user, %{bike_id: bike.id})
    %{user: user, user_bike: user_bike}
  end

  describe "add_mod/2" do
    test "adds a mod to a user_bike", %{user_bike: user_bike} do
      assert {:ok, mod} =
               UserBikes.add_mod(user_bike, %{
                 "mod_type" => "exhaust",
                 "description" => "Full titanium closed-course system"
               })

      assert mod.mod_type == :exhaust
      assert mod.description == "Full titanium closed-course system"
      assert mod.user_bike_id == user_bike.id
      assert mod.position == 0
    end

    test "adds a mod with all optional fields", %{user_bike: user_bike} do
      assert {:ok, mod} =
               UserBikes.add_mod(user_bike, %{
                 "mod_type" => "suspension",
                 "description" => "Re-valved forks with heavier springs",
                 "brand" => "Cogent Dynamics",
                 "cost_cents" => "89900",
                 "installed_at" => "2026-01-15",
                 "rating" => "5"
               })

      assert mod.mod_type == :suspension
      assert mod.brand == "Cogent Dynamics"
      assert mod.cost_cents == 89900
      assert mod.installed_at == ~D[2026-01-15]
      assert mod.rating == 5
    end

    test "auto-increments position", %{user_bike: user_bike} do
      {:ok, mod1} =
        UserBikes.add_mod(user_bike, %{"mod_type" => "exhaust", "description" => "First mod"})

      {:ok, mod2} =
        UserBikes.add_mod(user_bike, %{"mod_type" => "gearing", "description" => "Second mod"})

      {:ok, mod3} =
        UserBikes.add_mod(user_bike, %{"mod_type" => "tires", "description" => "Third mod"})

      assert mod1.position == 0
      assert mod2.position == 1
      assert mod3.position == 2
    end

    test "returns error changeset for invalid data", %{user_bike: user_bike} do
      assert {:error, changeset} =
               UserBikes.add_mod(user_bike, %{"mod_type" => "", "description" => ""})

      refute changeset.valid?
    end
  end

  describe "update_mod/2" do
    test "updates an existing mod", %{user_bike: user_bike} do
      {:ok, mod} =
        UserBikes.add_mod(user_bike, %{
          "mod_type" => "exhaust",
          "description" => "Stock replacement"
        })

      assert {:ok, updated} =
               UserBikes.update_mod(mod, %{
                 "description" => "Full titanium system",
                 "brand" => "Akrapovič"
               })

      assert updated.description == "Full titanium system"
      assert updated.brand == "Akrapovič"
    end
  end

  describe "delete_mod/1" do
    test "deletes a mod by ID", %{user_bike: user_bike} do
      {:ok, mod} =
        UserBikes.add_mod(user_bike, %{
          "mod_type" => "exhaust",
          "description" => "Full system"
        })

      assert {:ok, _deleted} = UserBikes.delete_mod(mod.id)
      assert UserBikes.list_mods(user_bike) == []
    end

    test "returns error for non-existent mod" do
      assert {:error, :not_found} = UserBikes.delete_mod(-1)
    end
  end

  describe "list_mods/1" do
    test "returns mods ordered by position", %{user_bike: user_bike} do
      {:ok, _} =
        UserBikes.add_mod(user_bike, %{"mod_type" => "exhaust", "description" => "First"})

      {:ok, _} =
        UserBikes.add_mod(user_bike, %{"mod_type" => "gearing", "description" => "Second"})

      {:ok, _} = UserBikes.add_mod(user_bike, %{"mod_type" => "tires", "description" => "Third"})

      mods = UserBikes.list_mods(user_bike)
      assert length(mods) == 3
      assert Enum.map(mods, & &1.position) == [0, 1, 2]
      assert Enum.map(mods, & &1.mod_type) == [:exhaust, :gearing, :tires]
    end

    test "returns empty list when no mods", %{user_bike: user_bike} do
      assert UserBikes.list_mods(user_bike) == []
    end
  end

  describe "change_mod/2" do
    test "returns a changeset" do
      changeset = UserBikes.change_mod(%UserBikeMod{})
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "get_user_bike/1 preloads mods" do
    test "includes mods in preloaded user_bike", %{user: user, user_bike: user_bike} do
      {:ok, _} =
        UserBikes.add_mod(user_bike, %{"mod_type" => "exhaust", "description" => "Full system"})

      {:ok, _} =
        UserBikes.add_mod(user_bike, %{"mod_type" => "gearing", "description" => "51-tooth rear"})

      loaded = UserBikes.get_user_bike(user)
      assert length(loaded.mods) == 2
      assert Enum.map(loaded.mods, & &1.mod_type) == [:exhaust, :gearing]
    end
  end
end
