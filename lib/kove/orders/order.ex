defmodule Kove.Orders.Order do
  @moduledoc """
  Order schema for future e-commerce features.

  ## Status: Future Feature

  This module is currently unused but retained as a placeholder
  for planned order management and lead capture functionality.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :customer_name, :string
    field :customer_email, :string
    field :customer_phone, :string
    field :notes, :string

    belongs_to :bike, Kove.Bikes.Bike

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:bike_id, :customer_name, :customer_email, :customer_phone, :notes])
    |> validate_required([:bike_id, :customer_name, :customer_email])
    |> validate_format(:customer_email, ~r/@/)
  end
end
