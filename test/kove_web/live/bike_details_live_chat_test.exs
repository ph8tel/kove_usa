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
      Kove.Repo.insert(Kove.Engines.Engine.changeset(%Kove.Engines.Engine{}, engine_attrs))

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

      view
      |> form("#kovy-chat-form", %{message: "What engine does this have?"})
      |> render_submit()

      # Let the parent process the relayed {:chat_send, msg}
      html = render(view)

      assert html =~ "What engine does this have?"
      # The loading spinner should appear
      assert html =~ "loading"
    end

    test "ignores empty messages", %{conn: conn, bike: bike} do
      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("#kovy-chat-form", %{message: "  "})
      |> render_submit()

      html = render(view)

      # Should still show the empty state
      assert html =~ "Ask me anything"
    end

    test "quick-ask button sends a message", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> element("#kovy-chat button", "vs KTM?")
      |> render_click()

      html = render(view)

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
      |> form("#kovy-chat-form", %{message: "Tell me about the engine"})
      |> render_submit()

      # Let the parent process the relayed message
      render(view)

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
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      render(view)

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
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      render(view)

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
      |> form("#kovy-chat-form", %{message: "Tell me about this bike"})
      |> render_submit()

      render(view)

      # Wait for the GenServer task to call our mock
      assert_receive :groq_called, 2_000

      # Let the LiveView process all the messages
      html = render(view)

      assert html =~ "Tell me about this bike"
      assert html =~ "The 800X is awesome."
      assert html =~ "Ask about this bike..."
    end
  end

  describe "retry_message" do
    test "retry button appears for retryable error types", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      render(view)

      for error_type <- [:timeout, :connection, :retry_exhausted] do
        send(view.pid, {:kovy_error, error_type, "Some error"})
        html = render(view)

        assert html =~ "Try again",
               "expected retry button for error_type=#{error_type}"

        assert has_element?(view, "button[phx-click='retry_message']"),
               "expected retry button element for error_type=#{error_type}"
      end
    end

    test "retry button does not appear for non-retryable errors", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      render(view)

      for error_type <- [:auth_failed, :rate_limited, :invalid_request, :server_error, :unknown] do
        send(view.pid, {:kovy_error, error_type, "Some error"})
        html = render(view)

        refute html =~ "Try again",
               "expected NO retry button for error_type=#{error_type}"
      end
    end

    test "clicking retry clears the error and shows streaming bubble", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("#kovy-chat-form", %{message: "Tell me about the engine"})
      |> render_submit()

      render(view)

      send(view.pid, {:kovy_error, :timeout, "⏳ Request timed out."})
      html = render(view)

      assert html =~ "Try again"

      view
      |> element("#kovy-chat-messages button[phx-click='retry_message']")
      |> render_click()

      render(view)
      html = render(view)

      # Error message should be gone, loading should be active
      refute html =~ "⏳ Request timed out."
      refute html =~ "Try again"
      assert html =~ "Kovy is thinking"
    end

    test "retry re-sends the original user message to KovyAssistant", %{conn: conn, bike: bike} do
      test_pid = self()
      call_count = :counters.new(1, [])

      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, pid ->
        :counters.add(call_count, 1, 1)
        send(test_pid, {:groq_called, :counters.get(call_count, 1)})
        send(pid, {:kovy_done})
        :ok
      end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      view
      |> form("#kovy-chat-form", %{message: "What is the seat height?"})
      |> render_submit()

      render(view)
      assert_receive {:groq_called, 1}, 2_000

      # Simulate a transient error
      send(view.pid, {:kovy_error, :connection, "📡 Connection lost."})
      render(view)

      # Click retry
      view
      |> element("#kovy-chat-messages button[phx-click='retry_message']")
      |> render_click()

      render(view)
      assert_receive {:groq_called, 2}, 2_000

      send(view.pid, {:kovy_chunk, "Seat height is 835mm."})
      send(view.pid, {:kovy_done})
      html = render(view)

      # Original user message still present, response rendered
      assert html =~ "What is the seat height?"
      assert html =~ "Seat height is 835mm."
    end

    test "retry does not double-fire when already loading", %{conn: conn, bike: bike} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Submit a message — now loading
      view
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      # Directly send the retry message while loading is true
      send(view.pid, {:chat_retry, "Hello"})
      html = render(view)

      # Should still be in loading state without crashing
      assert html =~ "Kovy is thinking"
    end
  end

  describe "tab switching" do
    test "set_tab event switches active tab", %{conn: conn, bike: bike} do
      {:ok, view, html} = live(conn, ~p"/bikes/#{bike.slug}")

      # Default tab is description
      assert html =~ "Description"

      html =
        view
        |> element("button[phx-click='set_tab'][phx-value-tab='engine']")
        |> render_click()

      assert html =~ "Engine"
    end
  end
end
