defmodule Kove.Orders.Order do
  @moduledoc """
  Order schema for the rider parts store.

  An order in "cart" status acts as the user's active shopping cart.
  Each user has at most one active cart at a time. When confirmed,
  the order progresses through: pending → confirmed → shipped → delivered.

  ## Status Lifecycle

      cart → pending → confirmed → shipped → delivered
                  ↘ cancelled

  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(cart pending confirmed shipped delivered cancelled)

  schema "orders" do
    field :status, :string, default: "cart"
    field :customer_name, :string
    field :customer_email, :string
    field :customer_phone, :string
    field :notes, :string
    field :shipping_name, :string
    field :shipping_address, :string
    field :tracking_number, :string
    field :shipped_at, :utc_datetime
    field :confirmed_at, :utc_datetime

    belongs_to :user, Kove.Accounts.User
    belongs_to :bike, Kove.Bikes.Bike
    has_many :items, Kove.Orders.OrderItem

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new cart order.
  Only status and user_id are needed; everything else is set later.
  """
  def cart_changeset(order, attrs) do
    order
    |> cast(attrs, [:status])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Changeset for confirming an order (moving from cart to pending).
  Requires customer contact info.
  """
  def confirm_changeset(order, attrs) do
    order
    |> cast(attrs, [
      :status,
      :customer_name,
      :customer_email,
      :customer_phone,
      :shipping_name,
      :shipping_address,
      :notes
    ])
    |> validate_required([:status, :customer_name, :customer_email])
    |> validate_format(:customer_email, ~r/@/)
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Changeset for updating order status (admin transitions).
  """
  def status_changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :tracking_number, :shipped_at, :confirmed_at])
    |> validate_required([:status])
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Returns all valid statuses.
  """
  def statuses, do: @statuses
end
