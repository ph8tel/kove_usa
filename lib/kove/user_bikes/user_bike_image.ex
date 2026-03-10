defmodule Kove.UserBikes.UserBikeImage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_bike_images" do
    field :url, :string
    field :storage_key, :string
    field :position, :integer, default: 0

    belongs_to :user_bike, Kove.UserBikes.UserBike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:url, :storage_key, :position])
    |> validate_required([:url])
    |> validate_url(:url)
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
