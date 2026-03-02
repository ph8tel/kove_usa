defmodule Kove.ChassisSpecs.ChassisSpec do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chassis_specs" do
    field :frame_type, :string
    field :front_suspension, :string
    field :front_travel, :string
    field :rear_suspension, :string
    field :rear_travel, :string
    field :front_brake, :string
    field :rear_brake, :string
    field :abs_system, :string
    field :wheels, :string
    field :tires, :string
    field :steering_angle, :string
    field :rake_angle, :string
    field :triple_clamp, :string

    belongs_to :bike, Kove.Bikes.Bike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chassis_spec, attrs) do
    chassis_spec
    |> cast(attrs, [
      :bike_id,
      :frame_type,
      :front_suspension,
      :front_travel,
      :rear_suspension,
      :rear_travel,
      :front_brake,
      :rear_brake,
      :abs_system,
      :wheels,
      :tires,
      :steering_angle,
      :rake_angle,
      :triple_clamp
    ])
    |> validate_required([:bike_id])
  end
end
