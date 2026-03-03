defmodule KoveWeb.StorefrontLiveChatTest do
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

  describe "storefront page mount with chat" do
    test "renders Kovy chat panel", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Kovy"
      assert html =~ "Your bike assistant"
      assert html =~ "our lineup"
    end

    test "shows catalog quick-ask buttons on initial load", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Best for beginners?"
      assert html =~ "Compare models"
      assert html =~ "Off-road pick?"
    end

    test "still renders the bike grid", %{conn: conn, bike: bike} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "KOVE MOTO"
      assert html =~ bike.name
    end
  end

  describe "send_message event" do
    test "adds user message and streaming assistant bubble", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

      # Submit via the component form
      view
      |> form("#kovy-chat-form", %{message: "Which bike for a beginner?"})
      |> render_submit()

      # Let the parent process the relayed {:chat_send, msg}
      html = render(view)

      assert html =~ "Which bike for a beginner?"
      # The loading spinner should appear
      assert html =~ "loading"
    end

    test "ignores empty messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "  "})
      |> render_submit()

      html = render(view)

      # Should still show the empty state
      assert html =~ "our lineup"
    end

    test "quick-ask button sends a message", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#kovy-chat button", "Best for beginners?")
      |> render_click()

      html = render(view)

      assert html =~ "Which Kove bike is best for a beginner?"
    end
  end

  describe "streaming callbacks" do
    test "kovy_chunk appends text to the assistant message", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "Compare the 800X models"})
      |> render_submit()

      # Let parent process the chat_send message
      render(view)

      # Simulate streaming chunks arriving
      send(view.pid, {:kovy_chunk, "The 800X comes in "})
      html = render(view)
      assert html =~ "The 800X comes in"

      send(view.pid, {:kovy_chunk, "three variants."})
      html = render(view)
      assert html =~ "three variants."
    end

    test "kovy_done clears loading state", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      render(view)

      send(view.pid, {:kovy_chunk, "Hi there!"})
      send(view.pid, {:kovy_done})
      html = render(view)

      assert html =~ "Hi there!"
      assert html =~ "Ask about any Kove bike..."
    end

    test "kovy_error shows error styling and clears loading", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      render(view)

      send(view.pid, {:kovy_error, "Something went wrong"})
      html = render(view)

      assert html =~ "Something went wrong"
      assert html =~ "border-error"
      assert html =~ "Ask about any Kove bike..."
    end

    test "full streaming conversation round-trip", %{conn: conn} do
      test_pid = self()

      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn messages, pid ->
        # Verify the system message contains catalog content
        [system | _rest] = messages
        assert system["role"] == "system"
        assert system["content"] =~ "catalog"

        send(test_pid, :groq_called)
        send(pid, {:kovy_chunk, "Great "})
        send(pid, {:kovy_chunk, "question! "})
        send(pid, {:kovy_chunk, "Here's the breakdown."})
        send(pid, {:kovy_done})
        :ok
      end)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "Compare the 800X and 450"})
      |> render_submit()

      assert_receive :groq_called, 2_000

      html = render(view)

      assert html =~ "Compare the 800X and 450"
      assert html =~ "the breakdown."
      assert html =~ "Ask about any Kove bike..."
    end
  end

  describe "retry_message" do
    test "retry button appears for retryable error types", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

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

    test "retry button does not appear for non-retryable errors", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

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

    test "clicking retry clears the error and shows streaming bubble", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "Best beginner bike?"})
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

      refute html =~ "⏳ Request timed out."
      refute html =~ "Try again"
      assert html =~ "Kovy is thinking"
    end

    test "retry re-sends the original user message to KovyAssistant", %{conn: conn} do
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

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "Which bike is best for off-road?"})
      |> render_submit()

      render(view)
      assert_receive {:groq_called, 1}, 2_000

      send(view.pid, {:kovy_error, :connection, "📡 Connection lost."})
      render(view)

      view
      |> element("#kovy-chat-messages button[phx-click='retry_message']")
      |> render_click()

      render(view)
      assert_receive {:groq_called, 2}, 2_000

      send(view.pid, {:kovy_chunk, "The 450 Rally is best for off-road."})
      send(view.pid, {:kovy_done})
      html = render(view)

      assert html =~ "Which bike is best for off-road?"
      assert html =~ "The 450 Rally is best for off-road."
    end

    test "retry does not double-fire when already loading", %{conn: conn} do
      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> stub(:stream_chat, fn _messages, _pid -> :ok end)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#kovy-chat-form", %{message: "Hello"})
      |> render_submit()

      # Directly send the retry message while loading is true
      send(view.pid, {:chat_retry, "Hello"})
      html = render(view)

      assert html =~ "Kovy is thinking"
    end
  end
end
