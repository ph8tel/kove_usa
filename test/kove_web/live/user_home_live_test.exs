defmodule KoveWeb.UserHomeLiveTest do
  use KoveWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kove.AccountsFixtures
  import Kove.BikesFixtures

  # -------------------------------------------------------------------------
  # No-bike state (new Google OAuth users, or users who skipped bike selection)
  # -------------------------------------------------------------------------

  describe "My Mods tab - no bike selected" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows the bike selection form", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/home")

      assert html =~ "No bike selected yet"
      assert has_element?(lv, "#select-bike-form")
    end

    test "shows all available bikes in the dropdown", %{conn: conn} do
      bike = bike_fixture()

      {:ok, lv, _html} = live(conn, ~p"/home")

      assert has_element?(lv, "#select-bike-dropdown option[value='#{bike.id}']")
    end

    test "does not show truck icon", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/home")

      refute html =~ "hero-truck"
    end

    test "selecting a bike updates the page and shows the mods section", %{conn: conn} do
      bike = bike_fixture()

      {:ok, lv, _html} = live(conn, ~p"/home")

      assert has_element?(lv, "#select-bike-form")

      lv
      |> form("#select-bike-form", %{"bike_id" => bike.id})
      |> render_submit()

      # After selection the form disappears and the mods section is shown
      refute has_element?(lv, "#select-bike-form")
      assert has_element?(lv, "#mod-form")
    end

    test "selecting a bike shows a success flash with the bike name", %{conn: conn} do
      bike = bike_fixture()

      {:ok, lv, _html} = live(conn, ~p"/home")

      lv
      |> form("#select-bike-form", %{"bike_id" => bike.id})
      |> render_submit()

      assert render(lv) =~ "added to your garage"
    end

    test "submitting without a bike shows an error flash", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/home")

      # Send the event manually to bypass HTML required attribute
      render_hook(lv, "select-bike", %{"bike_id" => ""})

      assert render(lv) =~ "Please select a bike"
    end
  end

  # -------------------------------------------------------------------------
  # With-bike state (normal users)
  # -------------------------------------------------------------------------

  describe "My Mods tab - bike already selected" do
    setup %{conn: conn} do
      user = user_fixture()
      bike = bike_fixture()
      {:ok, _user_bike} = Kove.UserBikes.create_user_bike(user, %{"bike_id" => bike.id})

      %{conn: log_in_user(conn, user), user: user, bike: bike}
    end

    test "shows the mods form instead of the bike-select form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/home")

      assert has_element?(lv, "#mod-form")
      refute has_element?(lv, "#select-bike-form")
    end

    test "does not show the no-bike message", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/home")

      refute html =~ "No bike selected yet"
    end
  end
end
