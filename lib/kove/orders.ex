defmodule Kove.Orders do
  @moduledoc """
  Context for managing orders and the shopping cart.

  An order in "cart" status serves as the user's shopping cart.
  Each user has at most one active cart at a time.
  """

  import Ecto.Query
  alias Kove.Repo
  alias Kove.Orders.Order
  alias Kove.Orders.OrderItem

  @doc """
  Returns the user's active cart (an order in "cart" status),
  creating one if it doesn't exist yet.
  """
  def get_or_create_cart(user) do
    case get_cart(user) do
      nil ->
        {:ok, order} =
          %Order{}
          |> Order.cart_changeset(%{status: "cart"})
          |> Ecto.Changeset.put_change(:user_id, user.id)
          |> Repo.insert()

        order |> Repo.preload(:items)

      cart ->
        cart
    end
  end

  @doc """
  Returns the user's active cart or nil.
  """
  def get_cart(user) do
    Order
    |> where(user_id: ^user.id, status: "cart")
    |> preload(items: :part_kit)
    |> Repo.one()
  end

  @doc """
  Returns the number of items in the user's cart.
  """
  def cart_item_count(user) do
    OrderItem
    |> join(:inner, [oi], o in Order, on: oi.order_id == o.id)
    |> where([oi, o], o.user_id == ^user.id and o.status == "cart")
    |> select([oi], sum(oi.quantity))
    |> Repo.one() || 0
  end

  @doc """
  Adds a part kit to the user's cart. If the kit is already in the cart,
  increments the quantity.

  Returns `{:ok, order_item}` on success.
  """
  def add_kit_to_cart(user, part_kit) do
    cart = get_or_create_cart(user)

    case Repo.get_by(OrderItem, order_id: cart.id, part_kit_id: part_kit.id) do
      nil ->
        %OrderItem{}
        |> OrderItem.changeset(%{
          quantity: 1,
          unit_price_cents: part_kit.price_cents,
          name_snapshot: part_kit.name,
          part_kit_id: part_kit.id
        })
        |> Ecto.Changeset.put_change(:order_id, cart.id)
        |> Repo.insert()

      existing ->
        existing
        |> Ecto.Changeset.change(quantity: existing.quantity + 1)
        |> Repo.update()
    end
  end

  @doc """
  Removes an order item from the user's cart.
  """
  def remove_cart_item(user, item_id) do
    cart = get_cart(user)

    if cart do
      case Repo.get_by(OrderItem, id: item_id, order_id: cart.id) do
        nil -> {:error, :not_found}
        item -> Repo.delete(item)
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Confirms the cart, transitioning it from "cart" to "pending".
  Requires customer contact info.

  Returns `{:ok, order}` or `{:error, changeset}`.
  """
  def confirm_order(user, attrs \\ %{}) do
    case get_cart(user) do
      nil ->
        {:error, :no_cart}

      %{items: []} ->
        {:error, :empty_cart}

      cart ->
        cart
        |> Order.confirm_changeset(Map.merge(attrs, %{status: "pending"}))
        |> Ecto.Changeset.put_change(
          :confirmed_at,
          DateTime.truncate(DateTime.utc_now(), :second)
        )
        |> Repo.update()
    end
  end

  @doc """
  Lists all non-cart orders for a user, most recent first.
  """
  def list_user_orders(user) do
    Order
    |> where(user_id: ^user.id)
    |> where([o], o.status != "cart")
    |> order_by([o], desc: o.confirmed_at)
    |> preload(items: :part_kit)
    |> Repo.all()
  end

  @doc """
  Gets a single order belonging to a user.
  """
  def get_user_order(user, order_id) do
    Order
    |> where(user_id: ^user.id)
    |> preload(items: :part_kit)
    |> Repo.get(order_id)
  end

  @doc """
  Updates the status of an order (admin function).
  """
  def update_status(%Order{} = order, attrs) do
    order
    |> Order.status_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Calculates the total price in cents for an order.
  """
  def order_total_cents(%Order{items: items}) when is_list(items) do
    Enum.reduce(items, 0, fn item, acc ->
      acc + item.unit_price_cents * item.quantity
    end)
  end

  def order_total_cents(_), do: 0
end
