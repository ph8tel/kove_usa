defmodule Kove.BikeFeatures.BikeFeature do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bike_features" do
    field :name, :string
    field :position, :integer

    belongs_to :bike, Kove.Bikes.Bike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bike_feature, attrs) do
    bike_feature
    |> cast(attrs, [:bike_id, :name, :position])
    |> validate_required([:bike_id, :name])
  end
end
