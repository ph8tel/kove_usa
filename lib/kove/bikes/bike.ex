defmodule Kove.Bikes.Bike do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bikes" do
    field :name, :string
    field :year, :integer
    field :variant, :string
    field :slug, :string
    field :status, Ecto.Enum, values: [:street_legal, :competition]
    field :category, Ecto.Enum, values: [:adv, :rally, :mx]
    field :msrp_cents, :integer
    field :hero_image_url, :string
    field :exhaust_override, :string
    field :sprocket_override, :string
    field :ecu_override, :string

    belongs_to :engine, Kove.Engines.Engine
    has_one :chassis_spec, Kove.ChassisSpecs.ChassisSpec
    has_one :dimension, Kove.Dimensions.Dimension
    has_many :bike_features, Kove.BikeFeatures.BikeFeature
    has_many :images, Kove.Images.Image
    has_many :descriptions, Kove.Descriptions.Description

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bike, attrs) do
    bike
    |> cast(attrs, [
      :engine_id,
      :name,
      :year,
      :variant,
      :slug,
      :status,
      :category,
      :msrp_cents,
      :hero_image_url,
      :exhaust_override,
      :sprocket_override,
      :ecu_override
    ])
    |> validate_required([:engine_id, :name, :year, :variant, :slug, :status, :category])
    |> unique_constraint(:slug)
  end
end
