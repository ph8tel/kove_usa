defmodule Kove.KovyAssistant.GroqTest do
  use ExUnit.Case, async: true

  alias Kove.KovyAssistant.Groq

  # ── SSE Parsing (unit tests — no HTTP involved) ──────────────────────
  #
  # We test the private parse/split helpers indirectly via stream_chat
  # with a nil API key, plus we can test the module‑level API directly.

  describe "api_key_available?/0" do
    test "returns a boolean" do
      # In test env there is no GROQ_API_KEY set, so this should be false
      # unless config is explicitly set. Either way, it must be a boolean.
      assert is_boolean(Groq.api_key_available?())
    end
  end

  describe "stream_chat/2 without API key" do
    test "sends :kovy_error when API key is missing" do
      # Temporarily clear any configured key so we hit the nil branch
      prev = Application.get_env(:kove, :groq_api_key)
      Application.delete_env(:kove, :groq_api_key)
      # Also ensure env var is absent for this test
      System.delete_env("GROQ_API_KEY")

      result = Groq.stream_chat([%{"role" => "user", "content" => "hi"}], self())

      assert result == :error
      assert_receive {:kovy_error, error_type, reason}
      assert error_type == :auth_failed
      assert reason =~ "GROQ_API_KEY not configured"

      # Restore
      if prev, do: Application.put_env(:kove, :groq_api_key, prev)
    end
  end

  describe "chat/1 without API key" do
    test "returns error tuple when API key is missing" do
      prev = Application.get_env(:kove, :groq_api_key)
      Application.delete_env(:kove, :groq_api_key)
      System.delete_env("GROQ_API_KEY")

      assert {:error, "GROQ_API_KEY not configured"} =
               Groq.chat([%{"role" => "user", "content" => "hi"}])

      if prev, do: Application.put_env(:kove, :groq_api_key, prev)
    end
  end
end
