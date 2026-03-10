defmodule Kove.UserBikes.UserBike do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_bikes" do
    field :bike_image_url, :string
    field :nickname, :string

    belongs_to :user, Kove.Accounts.User
    belongs_to :bike, Kove.Bikes.Bike
    has_many :images, Kove.UserBikes.UserBikeImage

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_bike, attrs) do
    user_bike
    |> cast(attrs, [:bike_id, :bike_image_url, :nickname])
    |> validate_url(:bike_image_url)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      uri = URI.parse(value)

      if uri.scheme in ["http", "https"] and is_binary(uri.host) and uri.host != "" do
        []
      else
        [{field, "must be a valid URL starting with http:// or https://"}]
      end
    end)
  end
end
