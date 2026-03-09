defmodule Kove.KovyAssistant.InputSanitizer do
  @moduledoc """
  Sanitizes user chat input before it reaches the Groq API or is used for
  keyword matching.

  ## Threat model

  User messages in this application are handled as follows:
    - They are interpolated into an LLM prompt string (prompt-injection risk)
    - They are used for Elixir string matching in `Prompt.relevant_bikes/2` (no SQL risk)
    - They are forwarded to the Groq API as message content (API-abuse risk)

  There is **no SQL injection risk** because user text never reaches an Ecto
  query. The primary concerns are:

    1. **Prompt injection** — user tries to override system instructions or
       extract the system prompt contents.
    2. **Token flooding** — excessively long messages inflate API cost.
    3. **Control-character smuggling** — null bytes or invisible control
       characters used to confuse parsing.
    4. **Role spoofing** — embedding fake "system:" or "assistant:" prefixes
       to confuse the model.
  """

  require Logger

  # Maximum characters accepted per user message.
  @max_message_length 2_000

  # Patterns that indicate a prompt injection or jailbreak attempt.
  # We log the attempt and keep the text (so the LLM's own guardrails also
  # fire) rather than silently dropping the message.
  @injection_patterns [
    ~r/ignore\s+(all\s+)?(previous|above|prior)\s+instructions/i,
    ~r/forget\s+(all\s+)?(previous|above|prior)\s+instructions/i,
    ~r/disregard\s+(all\s+)?(previous|above|prior)/i,
    ~r/override\s+(your\s+)?(instructions?|rules?|system\s+prompt)/i,
    ~r/reveal\s+(your\s+)?(system\s+)?prompt/i,
    ~r/print\s+(your\s+)?(system\s+)?prompt/i,
    ~r/show\s+(me\s+)?(your\s+)?(system\s+)?prompt/i,
    ~r/what\s+(is|are)\s+(your\s+)?(system\s+)?instructions/i,
    ~r/\bDAN\s+mode\b/i,
    ~r/\bjailbreak\b/i,
    ~r/you\s+are\s+now\s+(a\s+|an\s+)?(?!kovy)/i,
    ~r/act\s+as\s+(a\s+|an\s+)?(?!kovy|motorcycle|bike)/i,
    ~r/pretend\s+(you\s+are|to\s+be)/i,
    # Fake role prefixes smuggled into a user turn
    ~r/^\s*(system|assistant)\s*:/i,
    ~r/<\s*\/?(system|prompt|instructions?)\s*>/i
  ]

  @doc """
  Sanitizes a full chat history list, applying per-message sanitization to
  every entry. Returns the cleaned history.
  """
  @spec sanitize_history(list(map())) :: list(map())
  def sanitize_history(chat_history) when is_list(chat_history) do
    Enum.map(chat_history, &sanitize_message/1)
  end

  @doc """
  Sanitizes a single message map (`%{role: atom, content: binary}`).
  Strips control characters, enforces length limits, and logs injection
  attempts on user messages.
  """
  @spec sanitize_message(map()) :: map()
  def sanitize_message(%{role: role, content: content} = msg) when is_binary(content) do
    sanitized =
      content
      |> strip_control_chars()
      |> truncate()
      |> detect_injection(role)

    %{msg | content: sanitized}
  end

  def sanitize_message(msg), do: msg

  @doc """
  Sanitizes a raw string used for internal purposes such as keyword matching.
  Strips control characters and enforces the length limit but does not log
  injection patterns (the string is not sent to the model).
  """
  @spec sanitize_query(binary()) :: binary()
  def sanitize_query(text) when is_binary(text) do
    text
    |> strip_control_chars()
    |> truncate()
  end

  def sanitize_query(other), do: other

  # ── Private helpers ──────────────────────────────────────────────────

  # Remove null bytes and ASCII control characters except tab (0x09),
  # newline (0x0A), and carriage return (0x0D).
  defp strip_control_chars(text) when is_binary(text) do
    String.replace(text, ~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
  end

  defp truncate(text) when is_binary(text) do
    if String.length(text) > @max_message_length do
      Logger.warning("KovyAssistant.InputSanitizer: message truncated",
        original_length: String.length(text),
        max_length: @max_message_length
      )

      String.slice(text, 0, @max_message_length) <> " […truncated]"
    else
      text
    end
  end

  # Only scan user-role messages — assistant turns are already produced by the
  # model and system turns are produced by our own code.
  defp detect_injection(text, :user) when is_binary(text) do
    if injection_attempt?(text) do
      Logger.warning("KovyAssistant.InputSanitizer: possible prompt-injection attempt detected",
        snippet: String.slice(text, 0, 150)
      )
    end

    text
  end

  defp detect_injection(text, _role), do: text

  defp injection_attempt?(text) do
    Enum.any?(@injection_patterns, &Regex.match?(&1, text))
  end
end
