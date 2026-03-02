defmodule Kove.Dimensions.Dimension do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dimensions" do
    field :weight, :string
    field :weight_type, Ecto.Enum, values: [:dry, :curb]
    field :fuel_capacity, :string
    field :estimated_range, :string
    field :overall_size, :string
    field :wheelbase, :string
    field :seat_height, :string
    field :ground_clearance, :string

    belongs_to :bike, Kove.Bikes.Bike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(dimension, attrs) do
    dimension
    |> cast(attrs, [
      :bike_id,
      :weight,
      :weight_type,
      :fuel_capacity,
      :estimated_range,
      :overall_size,
      :wheelbase,
      :seat_height,
      :ground_clearance
    ])
    |> validate_required([:bike_id])
  end
end
