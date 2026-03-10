defmodule Kove.PartsFixtures do
  @moduledoc """
  Test fixtures for creating part kits and compatibilities.
  """

  alias Kove.Repo
  alias Kove.Parts.PartKit
  alias Kove.Parts.PartKitCompatibility

  @doc """
  Creates a part kit fixture with optional attribute overrides.
  """
  def part_kit_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    defaults = %{
      sku: "TEST-KIT-#{unique}",
      name: "Test Oil Change Kit #{unique}",
      description: "Test oil change kit description",
      price_cents: 4999
    }

    {:ok, kit} =
      %PartKit{}
      |> PartKit.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    kit
  end

  @doc """
  Creates a part kit with engine compatibility.

  Returns `{kit, compatibility}`.
  """
  def part_kit_with_engine_fixture(engine, attrs \\ %{}) do
    kit = part_kit_fixture(attrs)

    {:ok, compat} =
      %PartKitCompatibility{}
      |> PartKitCompatibility.changeset(%{part_kit_id: kit.id, engine_id: engine.id})
      |> Repo.insert()

    {kit, compat}
  end
end
