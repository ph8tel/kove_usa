defmodule Kove.Parts do
  @moduledoc """
  Context for managing part kits and their engine compatibility.
  """

  import Ecto.Query
  alias Kove.Repo
  alias Kove.Parts.PartKit
  alias Kove.Parts.PartKitCompatibility

  @doc """
  Returns all active part kits compatible with a given bike's engine.
  Preloads engine compatibilities.
  """
  def list_kits_for_bike(%{engine_id: engine_id}) do
    PartKit
    |> join(:inner, [pk], c in PartKitCompatibility,
      on: c.part_kit_id == pk.id and c.engine_id == ^engine_id
    )
    |> where([pk], pk.active == true)
    |> order_by([pk], asc: pk.name)
    |> preload(:compatibilities)
    |> Repo.all()
  end

  def list_kits_for_bike(_), do: []

  @doc """
  Returns all active part kits.
  """
  def list_kits do
    PartKit
    |> where([pk], pk.active == true)
    |> order_by([pk], asc: pk.name)
    |> preload(:compatibilities)
    |> Repo.all()
  end

  @doc """
  Gets a single part kit by ID.

  Raises `Ecto.NoResultsError` if the PartKit does not exist.
  """
  def get_kit!(id) do
    PartKit
    |> preload(:compatibilities)
    |> Repo.get!(id)
  end

  @doc """
  Gets a single part kit by ID, returns nil if not found.
  """
  def get_kit(id) do
    PartKit
    |> preload(:compatibilities)
    |> Repo.get(id)
  end

  @doc """
  Creates a part kit.
  """
  def create_kit(attrs) do
    %PartKit{}
    |> PartKit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Adds an engine compatibility to a part kit.
  """
  def add_compatibility(part_kit_id, engine_id) do
    %PartKitCompatibility{}
    |> PartKitCompatibility.changeset(%{part_kit_id: part_kit_id, engine_id: engine_id})
    |> Repo.insert()
  end

  @doc """
  Returns the oil change kit compatible with the given bike, or nil.

  This is a convenience function for the maintenance tab. It finds the
  first active kit whose name contains "Oil Change" that is compatible
  with the bike's engine.
  """
  def oil_change_kit_for_bike(%{engine_id: engine_id}) do
    PartKit
    |> join(:inner, [pk], c in PartKitCompatibility,
      on: c.part_kit_id == pk.id and c.engine_id == ^engine_id
    )
    |> where([pk], pk.active == true)
    |> where([pk], ilike(pk.name, "%Oil Change%"))
    |> limit(1)
    |> Repo.one()
  end

  def oil_change_kit_for_bike(_), do: nil

  @doc """
  Returns a changeset for tracking part kit changes.
  """
  def change_kit(%PartKit{} = kit, attrs \\ %{}) do
    PartKit.changeset(kit, attrs)
  end
end
