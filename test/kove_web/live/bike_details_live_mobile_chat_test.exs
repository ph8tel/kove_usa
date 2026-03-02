defmodule KoveWeb.BikeDetailsLiveMobileChatTest do
  use KoveWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    engine_attrs = %{
      platform_name: "800X (799cc DOHC Parallel Twin)",
      engine_type: "Twin Cylinder, DOHC",
      displacement: "799cc",
      bore_x_stroke: "88mm × 65.7mm",
      cooling: "Liquid-Cooled",
      fuel_system: "Bosch EFI",
      transmission: "6-Speed",
      clutch: "Oil Bath, Multi-Disc",
      starter: "Electric"
    }

    {:ok, engine} =
      Kove.Repo.insert(Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, engine_attrs))

    bike_attrs = %{
      engine_id: engine.id,
      name: "2026 Kove 800X Rally",
      year: 2026,
      variant: "Rally",
      slug: "2026-kove-800x-rally",
      status: :street_legal,
      category: :adv,
      msrp_cents: 1_299_900
    }

    {:ok, bike} =
      Kove.Repo.insert(Kove.Bikes.Bike.changeset(%Kove.Bikes.Bike{}, bike_attrs))

    {:ok, bike: bike}
  end

  describe "mobile chat FAB" do
    test "shows FAB button on mount", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert has_element?(view, "#kovy-chat-fab")
    end

    test "FAB is hidden when chat drawer is open", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view |> element("#kovy-chat-fab") |> render_click()

      refute has_element?(view, "#kovy-chat-fab")
    end
  end

  describe "mobile chat drawer" do
    test "drawer is hidden on mount", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      refute has_element?(view, "#kovy-chat-drawer")
    end

    test "toggle_chat opens the drawer", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view |> element("#kovy-chat-fab") |> render_click()

      assert has_element?(view, "#kovy-chat-drawer")
    end

    test "toggle_chat closes the drawer when open", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Open
      view |> element("#kovy-chat-fab") |> render_click()
      assert has_element?(view, "#kovy-chat-drawer")

      # Close
      view |> element("#kovy-chat-close") |> render_click()
      refute has_element?(view, "#kovy-chat-drawer")
    end

    test "drawer has a close button", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view |> element("#kovy-chat-fab") |> render_click()

      assert has_element?(view, "#kovy-chat-close")
    end

    test "drawer shows Kovy header with bike name", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html = view |> element("#kovy-chat-fab") |> render_click()

      assert html =~ "Kovy"
      assert html =~ bike.name
    end

    test "drawer shows quick-ask buttons when no messages", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html = view |> element("#kovy-chat-fab") |> render_click()

      assert html =~ "vs KTM?"
      assert html =~ "Maintenance?"
      assert html =~ "Upgrades?"
    end

    test "drawer has chat input form", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view |> element("#kovy-chat-fab") |> render_click()

      assert has_element?(view, "#kovy-chat-mobile-form")
      assert has_element?(view, "#kovy-chat-mobile-form input[name=message]")
    end

    test "drawer has mobile-specific ScrollBottom hook", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view |> element("#kovy-chat-fab") |> render_click()

      assert has_element?(view, "#kovy-chat-mobile-messages[phx-hook=ScrollBottom]")
    end
  end

  describe "mobile chat auto-open on send" do
    test "sending a message auto-opens mobile drawer", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> Mox.stub(:api_key_available?, fn -> true end)
      |> Mox.stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Chat drawer should be closed initially
      refute has_element?(view, "#kovy-chat-drawer")

      # Send a message — drawer should auto-open
      view
      |> form("#kovy-chat-form", %{message: "Tell me about this bike"})
      |> render_submit()

      assert has_element?(view, "#kovy-chat-drawer")
    end
  end
end
