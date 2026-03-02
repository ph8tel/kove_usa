defmodule Kove.KovyAssistantTest do
  use Kove.DataCase, async: false

  import Mox

  alias Kove.KovyAssistant

  # Global mode so expectations propagate to GenServer → Task processes
  setup :set_mox_global
  setup :verify_on_exit!

  # We need an engine in the DB because the Prompt module calls Bikes helpers
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
      name: "2026 Kove 800X Pro",
      year: 2026,
      variant: "Pro",
      slug: "2026-kove-800x-pro",
      status: :street_legal,
      category: :adv,
      msrp_cents: 1_299_900,
      hero_image_url: "https://example.com/hero.jpg"
    }

    {:ok, bike} =
      Kove.Repo.insert(Kove.Bikes.Bike.changeset(%Kove.Bikes.Bike{}, bike_attrs))

    # Preload all associations like the real code path does
    bike = Kove.Bikes.get_bike!(bike.id)
    {:ok, bike: bike}
  end

  describe "send_message/3" do
    test "calls stream_chat on the configured Groq module with correct messages", %{bike: bike} do
      caller = self()

      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> expect(:stream_chat, fn messages, pid ->
        # Should have system prompt + user message = 2 messages
        assert length(messages) == 2
        assert [%{"role" => "system"}, %{"role" => "user", "content" => "Hello Kovy"}] = messages

        # The system prompt should contain bike context
        system = hd(messages)["content"]
        assert system =~ "You are Kovy"
        assert system =~ "800X"

        # Simulate streaming response back to the LiveView caller
        send(pid, {:kovy_chunk, "Hey "})
        send(pid, {:kovy_chunk, "there!"})
        send(pid, {:kovy_done})
        :ok
      end)

      chat_history = [%{role: :user, content: "Hello Kovy"}]
      KovyAssistant.send_message(bike, chat_history, caller)

      # The task runs asynchronously — give it a moment
      assert_receive {:kovy_chunk, "Hey "}, 2_000
      assert_receive {:kovy_chunk, "there!"}, 500
      assert_receive {:kovy_done}, 500
    end

    test "forwards :kovy_error when Groq mock returns error", %{bike: bike} do
      caller = self()

      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> false end)
      |> expect(:stream_chat, fn _messages, pid ->
        send(pid, {:kovy_error, "API key missing"})
        :error
      end)

      chat_history = [%{role: :user, content: "Tell me about the engine"}]
      KovyAssistant.send_message(bike, chat_history, caller)

      assert_receive {:kovy_error, "API key missing"}, 2_000
    end

    test "maps multi-turn conversation history correctly", %{bike: bike} do
      caller = self()

      Kove.KovyAssistant.GroqMock
      |> stub(:api_key_available?, fn -> true end)
      |> expect(:stream_chat, fn messages, pid ->
        # system + user + assistant + user = 4 messages
        assert length(messages) == 4
        assert Enum.at(messages, 0)["role"] == "system"
        assert Enum.at(messages, 1)["role"] == "user"
        assert Enum.at(messages, 1)["content"] == "First question"
        assert Enum.at(messages, 2)["role"] == "assistant"
        assert Enum.at(messages, 2)["content"] == "First answer"
        assert Enum.at(messages, 3)["role"] == "user"
        assert Enum.at(messages, 3)["content"] == "Follow up"

        send(pid, {:kovy_chunk, "Sure!"})
        send(pid, {:kovy_done})
        :ok
      end)

      history = [
        %{role: :user, content: "First question"},
        %{role: :assistant, content: "First answer"},
        %{role: :user, content: "Follow up"}
      ]

      KovyAssistant.send_message(bike, history, caller)
      assert_receive {:kovy_done}, 2_000
    end
  end
end
