defmodule Kove.Engines.Engine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "engines" do
    field :platform_name, :string
    field :engine_type, :string
    field :displacement, :string
    field :bore_x_stroke, :string
    field :cooling, :string
    field :compression_ratio, :string
    field :fuel_system, :string
    field :transmission, :string
    field :clutch, :string
    field :starter, :string
    field :max_power, :string
    field :max_torque, :string

    has_many :bikes, Kove.Bikes.Bike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(engine, attrs) do
    engine
    |> cast(attrs, [
      :platform_name,
      :engine_type,
      :displacement,
      :bore_x_stroke,
      :cooling,
      :compression_ratio,
      :fuel_system,
      :transmission,
      :clutch,
      :starter,
      :max_power,
      :max_torque
    ])
    |> validate_required([
      :platform_name,
      :engine_type,
      :displacement,
      :bore_x_stroke,
      :cooling,
      :fuel_system,
      :transmission,
      :clutch,
      :starter
    ])
  end
end
