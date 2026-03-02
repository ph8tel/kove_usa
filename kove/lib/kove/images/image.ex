defmodule Kove.Images.Image do
  use Ecto.Schema
  import Ecto.Changeset

  schema "images" do
    field :alt, :string
    field :url, :string
    field :position, :integer
    field :is_hero, :boolean, default: false

    belongs_to :bike, Kove.Bikes.Bike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:bike_id, :alt, :url, :position, :is_hero])
    |> validate_required([:bike_id, :url])
  end
end
