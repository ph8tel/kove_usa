defmodule Kove.OrdersTest do
  use Kove.DataCase

  alias Kove.Orders
  import Kove.AccountsFixtures
  import Kove.BikesFixtures
  import Kove.PartsFixtures

  setup do
    user = user_fixture()
    engine = engine_fixture()
    _bike = bike_fixture(engine)
    {kit, _compat} = part_kit_with_engine_fixture(engine, %{name: "800X Oil Change Kit"})
    {:ok, user: user, kit: kit}
  end

  describe "get_or_create_cart/1" do
    test "creates a new cart when none exists", %{user: user} do
      cart = Orders.get_or_create_cart(user)
      assert cart.status == "cart"
      assert cart.user_id == user.id
    end

    test "returns existing cart when one exists", %{user: user} do
      cart1 = Orders.get_or_create_cart(user)
      cart2 = Orders.get_or_create_cart(user)
      assert cart1.id == cart2.id
    end
  end

  describe "cart_item_count/1" do
    test "returns 0 when no cart exists", %{user: user} do
      assert Orders.cart_item_count(user) == 0
    end

    test "returns total quantity of items in cart", %{user: user, kit: kit} do
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      assert Orders.cart_item_count(user) == 1

      # Adding again increments quantity
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      assert Orders.cart_item_count(user) == 2
    end
  end

  describe "add_kit_to_cart/2" do
    test "adds a kit to the cart", %{user: user, kit: kit} do
      {:ok, item} = Orders.add_kit_to_cart(user, kit)
      assert item.name_snapshot == kit.name
      assert item.unit_price_cents == kit.price_cents
      assert item.quantity == 1
      assert item.part_kit_id == kit.id
    end

    test "increments quantity when kit already in cart", %{user: user, kit: kit} do
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      {:ok, item} = Orders.add_kit_to_cart(user, kit)
      assert item.quantity == 2
    end

    test "creates cart if none exists", %{user: user, kit: kit} do
      assert Orders.get_cart(user) == nil
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      assert Orders.get_cart(user) != nil
    end
  end

  describe "remove_cart_item/2" do
    test "removes an item from the cart", %{user: user, kit: kit} do
      {:ok, item} = Orders.add_kit_to_cart(user, kit)
      assert {:ok, _} = Orders.remove_cart_item(user, item.id)
      assert Orders.cart_item_count(user) == 0
    end

    test "returns error when no cart exists", %{user: user} do
      assert {:error, :not_found} = Orders.remove_cart_item(user, 0)
    end

    test "returns error when item not in cart", %{user: user, kit: kit} do
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      assert {:error, :not_found} = Orders.remove_cart_item(user, 0)
    end
  end

  describe "confirm_order/2" do
    test "confirms a cart with items", %{user: user, kit: kit} do
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)

      attrs = %{customer_name: "John Doe", customer_email: "john@example.com"}
      assert {:ok, order} = Orders.confirm_order(user, attrs)
      assert order.status == "pending"
      assert order.customer_name == "John Doe"
      assert order.confirmed_at != nil
    end

    test "returns error for empty cart", %{user: user} do
      _cart = Orders.get_or_create_cart(user)
      assert {:error, :empty_cart} = Orders.confirm_order(user)
    end

    test "returns error when no cart exists", %{user: user} do
      assert {:error, :no_cart} = Orders.confirm_order(user)
    end
  end

  describe "list_user_orders/1" do
    test "returns non-cart orders for user", %{user: user, kit: kit} do
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)

      {:ok, _order} =
        Orders.confirm_order(user, %{
          customer_name: "John",
          customer_email: "john@example.com"
        })

      orders = Orders.list_user_orders(user)
      assert length(orders) == 1
      assert hd(orders).status == "pending"
    end

    test "does not include cart orders", %{user: user, kit: kit} do
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      orders = Orders.list_user_orders(user)
      assert orders == []
    end

    test "returns empty list for user with no orders", %{user: user} do
      assert Orders.list_user_orders(user) == []
    end
  end

  describe "order_total_cents/1" do
    test "calculates total from items", %{user: user, kit: kit} do
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      {:ok, _item} = Orders.add_kit_to_cart(user, kit)
      cart = Orders.get_cart(user)
      assert Orders.order_total_cents(cart) == kit.price_cents * 2
    end

    test "returns 0 for nil" do
      assert Orders.order_total_cents(nil) == 0
    end
  end
end
