defmodule Kove.Descriptions.Description do
  use Ecto.Schema
  import Ecto.Changeset

  schema "descriptions" do
    field :kind, Ecto.Enum, values: [:marketing, :maintenance]
    field :body, :string
    field :position, :integer
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :bike, Kove.Bikes.Bike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(description, attrs) do
    description
    |> cast(attrs, [:bike_id, :kind, :body, :position, :embedding])
    |> validate_required([:bike_id, :kind, :body])
  end
end
