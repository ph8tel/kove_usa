defmodule Kove.Bikes do
  @moduledoc """
  The Bikes context — public API for querying the motorcycle catalog.
  """

  import Ecto.Query
  alias Kove.Repo
  alias Kove.Bikes.Bike

  @doc """
  Returns all bikes ordered by category then name, with engine and hero image preloaded.
  Used for the storefront grid cards.
  """
  def list_bikes do
    Bike
    |> order_by([b], asc: b.category, asc: b.name)
    |> preload([:engine, :images])
    |> Repo.all()
  end

  @doc """
  Returns all bikes with every association preloaded (engine, chassis, dimensions,
  features, images, descriptions). Used by the catalog chat prompt builder.
  """
  def list_bikes_full do
    descriptions_query = descriptions_without_embedding()

    Bike
    |> order_by([b], asc: b.category, asc: b.name)
    |> preload([
      :engine,
      :chassis_spec,
      :dimension,
      :bike_features,
      :images,
      descriptions: ^descriptions_query
    ])
    |> Repo.all()
  end

  @doc """
  Fetches a single bike by slug with all associations preloaded.
  Returns `nil` if not found.
  """
  def get_bike_by_slug(slug) do
    descriptions_query = descriptions_without_embedding()

    Bike
    |> where(slug: ^slug)
    |> preload([
      :engine,
      :chassis_spec,
      :dimension,
      :bike_features,
      :images,
      descriptions: ^descriptions_query
    ])
    |> Repo.one()
  end

  @doc """
  Fetches a single bike by id with all associations preloaded.
  Raises `Ecto.NoResultsError` if not found.
  """
  def get_bike!(id) do
    descriptions_query = descriptions_without_embedding()

    Bike
    |> preload([
      :engine,
      :chassis_spec,
      :dimension,
      :bike_features,
      :images,
      descriptions: ^descriptions_query
    ])
    |> Repo.get!(id)
  end

  # Selects all description columns except the large pgvector embedding,
  # so Postgres never transfers the vector data over the wire.
  defp descriptions_without_embedding do
    from(d in Kove.Descriptions.Description,
      select: struct(d, [:id, :bike_id, :kind, :body, :position, :inserted_at, :updated_at])
    )
  end

  @doc """
  Returns the hero image URL for a bike.
  Prioritizes the `hero_image_url` field from bikes table, then checks for an image marked `is_hero`,
  then falls back to the first image by position.
  """
  def hero_image_url(%Bike{images: images, hero_image_url: fallback}) when is_list(images) do
    hero = Enum.find(images, & &1.is_hero)
    first = Enum.min_by(images, & &1.position, fn -> nil end)

    cond do
      fallback && fallback != "" -> fallback
      hero -> hero.url
      first -> first.url
      true -> nil
    end
  end

  def hero_image_url(%Bike{hero_image_url: url}), do: url

  @doc """
  Formats an integer cents value as a USD string (e.g. 12999_00 → "$12,999").
  Returns "Contact for pricing" when nil.
  """
  def format_msrp(nil), do: "Contact for pricing"

  def format_msrp(cents) when is_integer(cents) do
    dollars = div(cents, 100)

    formatted =
      dollars
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

    "$#{formatted}"
  end

  @doc """
  Returns a human-readable category label.
  """
  def category_label(:adv), do: "Adventure"
  def category_label(:rally), do: "Rally"
  def category_label(:mx), do: "Motocross"
  def category_label(_), do: "Other"

  @doc """
  Returns a human-readable status badge label.
  """
  def status_label(:street_legal), do: "Street Legal"
  def status_label(:competition), do: "Competition Only"
  def status_label(_), do: ""
end
