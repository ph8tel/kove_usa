defmodule Kove.UserBikes.UserBikeMod do
  @moduledoc """
  Schema for rider modifications to their bike.

  Each mod captures what a rider has changed on their motorcycle — exhaust,
  gearing, suspension, etc. — along with optional brand, cost, install date,
  and a 1–5 star rating. The `embedding` column (vector(768)) enables
  semantic search across all rider mods for marketing analytics.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @mod_types ~w(exhaust gearing suspension clutch engine electronics intake controls tires protection lighting)a

  schema "user_bike_mods" do
    field :mod_type, Ecto.Enum, values: @mod_types
    field :description, :string
    field :brand, :string
    field :cost_cents, :integer
    field :installed_at, :date
    field :rating, :integer
    field :position, :integer, default: 0
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :user_bike, Kove.UserBikes.UserBike

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid mod type atoms.
  """
  def mod_types, do: @mod_types

  @doc """
  Returns a human-friendly label for a mod type atom.
  """
  def mod_type_label(:exhaust), do: "Exhaust"
  def mod_type_label(:gearing), do: "Gearing"
  def mod_type_label(:suspension), do: "Suspension"
  def mod_type_label(:clutch), do: "Clutch"
  def mod_type_label(:engine), do: "Engine"
  def mod_type_label(:electronics), do: "Electronics"
  def mod_type_label(:intake), do: "Intake"
  def mod_type_label(:controls), do: "Controls"
  def mod_type_label(:tires), do: "Tires"
  def mod_type_label(:protection), do: "Protection"
  def mod_type_label(:lighting), do: "Lighting"

  @doc false
  def changeset(mod, attrs) do
    mod
    |> cast(attrs, [
      :mod_type,
      :description,
      :brand,
      :cost_cents,
      :installed_at,
      :rating,
      :position
    ])
    |> validate_required([:mod_type, :description])
    |> validate_length(:description, min: 3, max: 500)
    |> validate_length(:brand, max: 100)
    |> validate_number(:cost_cents, greater_than_or_equal_to: 0)
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_inclusion(:mod_type, @mod_types)
  end
end
