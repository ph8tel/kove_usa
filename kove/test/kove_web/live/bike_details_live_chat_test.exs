defmodule KoveWeb.BikeDetailsLiveChatTest do
  use KoveWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox

  # Global mode so expectations propagate to GenServer → Task processes
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
      Kove.Repo.insert(
        Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, engine_attrs)
      )

    bike_attrs = %{
      engine_id: engine.id,
      name: "2026 Kove 800X Rally",
      year: 2026,
      variant: "Rally",
      slug: "2026-kove-800x-rally",
      status: :street_legal,
      category: :adv,
      msrp_cents: 1_299_900,
      hero_image_url: "https://example.com/hero.jpg"
    }

    {:ok, bike} =
      Kove.Repo.insert(Kove.Bikes.Bike.changeset(%Kove.Bikes.Bike{}, bike_attrs))

    {:ok, bike: bike}
  end

  describe "bike details page mount" do
    test "renders bike info and chat panel", %{conn: conn, bike: bike} do
      {:ok, _view, html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert html =~ bike.name
      assert html =~ "Kovy"
      assert html =~ "Your bike assistant"
      assert html =~ "Ask me anything"
    end

    test "shows quick-ask buttons on initial load", %{conn: conn, bike: bike} do
      {:ok, _view, html} = live(conn, ~p"/bikes/#{bike.slug}")

      assert html =~ "vs KTM?"
      assert html =~ "Maintenance?"
      assert html =~ "Upgrades?"
    end

    test "redirects to / for unknown slug", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/bikes/nonexistent-slug")
    end
  end

  describe "send_message event" do
    test "adds user message and streaming assistant bubble", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html =
        view
        |> form("form", %{message: "What engine does this have?"})
        |> render_submit()

      assert html =~ "What engine does this have?"
      # The loading spinner should appear
      assert html =~ "loading"
    end

    test "ignores empty messages", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html =
        view
        |> form("form", %{message: "  "})
        |> render_submit()

      # Should still show the empty state
      assert html =~ "Ask me anything"
    end

    test "quick-ask button sends a message", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      html =
        view
        |> element("button", "vs KTM?")
        |> render_click()

      assert html =~ "How does this compare to a KTM?"
    end
  end

  describe "streaming callbacks" do
    test "kovy_chunk appends text to the assistant message", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("form", %{message: "Tell me about the engine"})
      |> render_submit()

      # Simulate streaming chunks arriving
      send(view.pid, {:kovy_chunk, "The 800X features "})
      html = render(view)
      assert html =~ "The 800X features"

      send(view.pid, {:kovy_chunk, "a 799cc parallel twin."})
      html = render(view)
      assert html =~ "a 799cc parallel twin."
    end

    test "kovy_done clears loading state", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("form", %{message: "Hello"})
      |> render_submit()

      send(view.pid, {:kovy_chunk, "Hi there!"})
      send(view.pid, {:kovy_done})
      html = render(view)

      assert html =~ "Hi there!"
      # Input should no longer be disabled — placeholder should be the default
      assert html =~ "Ask about this bike..."
    end

    test "kovy_error shows error styling and clears loading", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("form", %{message: "Hello"})
      |> render_submit()

      send(view.pid, {:kovy_error, "Something went wrong"})
      html = render(view)

      assert html =~ "Something went wrong"
      assert html =~ "border-error"
      # Loading should be cleared
      assert html =~ "Ask about this bike..."
    end

    test "full streaming conversation round-trip", %{conn: conn, bike: bike} do
      test_pid = self()

      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn messages, pid ->
        # Verify message structure
        assert [%{"role" => "system"}, %{"role" => "user"}] = messages
        # Notify test that we were called
        send(test_pid, :groq_called)
        # Simulate streaming back
        send(pid, {:kovy_chunk, "Great "})
        send(pid, {:kovy_chunk, "question! "})
        send(pid, {:kovy_chunk, "The 800X is awesome."})
        send(pid, {:kovy_done})
        :ok
      end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("form", %{message: "Tell me about this bike"})
      |> render_submit()

      # Wait for the GenServer task to call our mock
      assert_receive :groq_called, 2_000

      # Let the LiveView process all the messages
      html = render(view)

      assert html =~ "Tell me about this bike"
      assert html =~ "The 800X is awesome."
      assert html =~ "Ask about this bike..."
    end
  end

  describe "tab switching" do
    test "set_tab event switches active tab", %{conn: conn, bike: bike} do
      {:ok, view, html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Default tab is marketing
      assert html =~ "Marketing"

      html =
        view
        |> element("button[phx-click='set_tab'][phx-value-tab='engine']")
        |> render_click()

      assert html =~ "Engine"
    end
  end
end
