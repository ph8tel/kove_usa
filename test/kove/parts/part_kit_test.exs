defmodule Kove.Parts.PartKitTest do
  use Kove.DataCase

  alias Kove.Parts.PartKit

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{sku: "OIL-KIT-800X", name: "800X Oil Change Kit", price_cents: 6499}
      changeset = PartKit.changeset(%PartKit{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with all fields" do
      attrs = %{
        sku: "OIL-KIT-800X",
        name: "800X Oil Change Kit",
        description: "Complete oil change kit",
        price_cents: 6499,
        active: true
      }

      changeset = PartKit.changeset(%PartKit{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset missing sku" do
      attrs = %{name: "800X Oil Change Kit", price_cents: 6499}
      changeset = PartKit.changeset(%PartKit{}, attrs)
      refute changeset.valid?
      assert :sku in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing name" do
      attrs = %{sku: "OIL-KIT-800X", price_cents: 6499}
      changeset = PartKit.changeset(%PartKit{}, attrs)
      refute changeset.valid?
      assert :name in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset missing price_cents" do
      attrs = %{sku: "OIL-KIT-800X", name: "800X Oil Change Kit"}
      changeset = PartKit.changeset(%PartKit{}, attrs)
      refute changeset.valid?
      assert :price_cents in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "invalid changeset with negative price_cents" do
      attrs = %{sku: "OIL-KIT-800X", name: "800X Oil Change Kit", price_cents: -100}
      changeset = PartKit.changeset(%PartKit{}, attrs)
      refute changeset.valid?
      assert :price_cents in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "price_cents of zero is valid" do
      attrs = %{sku: "FREE-KIT", name: "Free Kit", price_cents: 0}
      changeset = PartKit.changeset(%PartKit{}, attrs)
      assert changeset.valid?
    end

    test "enforces unique sku constraint" do
      attrs = %{sku: "UNIQUE-SKU", name: "Kit 1", price_cents: 1000}
      {:ok, _} = %PartKit{} |> PartKit.changeset(attrs) |> Kove.Repo.insert()

      assert {:error, changeset} =
               %PartKit{} |> PartKit.changeset(%{attrs | name: "Kit 2"}) |> Kove.Repo.insert()

      assert :sku in Enum.map(changeset.errors, fn {field, _} -> field end)
    end

    test "active defaults to true" do
      attrs = %{sku: "OIL-KIT-800X", name: "800X Oil Change Kit", price_cents: 6499}
      changeset = PartKit.changeset(%PartKit{}, attrs)
      assert Ecto.Changeset.get_field(changeset, :active) == true
    end
  end
end
