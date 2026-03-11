defmodule Kove.Parts.PartKitCompatibility do
  @moduledoc """
  Join schema linking part kits to compatible engine platforms.

  A part kit may be compatible with one or more engines. This enables
  engine-specific maintenance kits (e.g. oil change kits sized per engine).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "part_kit_compatibilities" do
    belongs_to :part_kit, Kove.Parts.PartKit
    belongs_to :engine, Kove.Engines.Engine

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(compat, attrs) do
    compat
    |> cast(attrs, [:part_kit_id, :engine_id])
    |> validate_required([:part_kit_id, :engine_id])
    |> unique_constraint([:part_kit_id, :engine_id])
  end
end
