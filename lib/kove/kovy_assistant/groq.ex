defmodule Kove.KovyAssistant.Groq do
  @moduledoc """
  HTTP client for the Groq chat‑completion API.

  Supports both synchronous and streaming modes.  In streaming mode,
  SSE chunks are parsed and forwarded to a caller PID as messages:

    * `{:kovy_chunk, text}`  — a token fragment
    * `{:kovy_done}`         — stream finished
    * `{:kovy_error, reason}` — something went wrong
  """

  @behaviour Kove.KovyAssistant.GroqBehaviour

  require Logger

  @groq_url "https://api.groq.com/openai/v1/chat/completions"
  @default_model "llama-3.3-70b-versatile"

  defp api_key do
    Application.get_env(:kove, :groq_api_key) || System.get_env("GROQ_API_KEY")
  end

  @doc "Returns true if the Groq API key is available."
  @impl true
  def api_key_available?, do: api_key() != nil

  # ── Public API ───────────────────────────────────────────────────────

  @doc """
  Streams a chat completion from Groq.

  Sends `{:kovy_chunk, text}`, `{:kovy_done}`, or `{:kovy_error, reason}`
  messages to `caller_pid`.
  """
  @impl true
  def stream_chat(messages, caller_pid) do
    case api_key() do
      nil ->
        send(caller_pid, {:kovy_error, "GROQ_API_KEY not configured. Set the environment variable and restart."})
        :error

      key ->
        do_stream(messages, key, caller_pid)
    end
  end

  @doc """
  Synchronous (non‑streaming) chat completion.

  Returns `{:ok, content}` or `{:error, reason}`.
  """
  @impl true
  def chat(messages) do
    case api_key() do
      nil -> {:error, "GROQ_API_KEY not configured"}
      key -> do_sync(messages, key)
    end
  end

  # ── Streaming ────────────────────────────────────────────────────────

  defp do_stream(messages, api_key, caller_pid) do
    body =
      Jason.encode!(%{
        "model" => @default_model,
        "messages" => messages,
        "temperature" => 0.7,
        "max_tokens" => 1024,
        "stream" => true
      })

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    Logger.info("Groq: starting streaming request to #{@default_model}")

    # We buffer partial SSE lines across chunks in the process dictionary.
    Process.put(:sse_buffer, "")
    Process.put(:sse_chunk_count, 0)

    try do
      resp =
        Req.post!(@groq_url,
          headers: headers,
          body: body,
          receive_timeout: 60_000,
          into: fn {:data, chunk}, {req, resp} ->
            Process.put(:sse_chunk_count, Process.get(:sse_chunk_count, 0) + 1)

            buffer = Process.get(:sse_buffer, "") <> chunk
            {lines, remaining} = split_sse_buffer(buffer)
            Process.put(:sse_buffer, remaining)

            for line <- lines do
              case parse_sse_line(line) do
                {:ok, content} -> send(caller_pid, {:kovy_chunk, content})
                :done -> :ok
                :skip -> :ok
              end
            end

            {:cont, {req, resp}}
          end
        )

      chunk_count = Process.get(:sse_chunk_count, 0)
      Logger.info("Groq: stream finished — status=#{resp.status}, chunks=#{chunk_count}")

      if resp.status == 200 do
        send(caller_pid, {:kovy_done})
      else
        # Non-200: the into callback received error JSON, not SSE.
        # Try to extract the error message from the response.
        error_body =
          case resp.body do
            %{"error" => %{"message" => msg}} -> msg
            body when is_binary(body) -> body
            other -> inspect(other)
          end

        Logger.error("Groq API error (#{resp.status}): #{error_body}")
        send(caller_pid, {:kovy_error, "Groq API error: #{error_body}"})
      end

      :ok
    rescue
      e ->
        Logger.error("Groq streaming error: #{Exception.message(e)}")

        send(
          caller_pid,
          {:kovy_error, "Something went wrong reaching Kovy's brain. Please try again."}
        )

        :error
    end
  end

  # ── Synchronous ──────────────────────────────────────────────────────

  defp do_sync(messages, api_key) do
    body =
      Jason.encode!(%{
        "model" => @default_model,
        "messages" => messages,
        "temperature" => 0.7,
        "max_tokens" => 1024,
        "stream" => false
      })

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    case Req.post(@groq_url, headers: headers, body: body) do
      {:ok, %{status: 200, body: body}} ->
        content = get_in(body, ["choices", Access.at(0), "message", "content"])
        {:ok, content || ""}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Groq API returned #{status}: #{inspect(body)}")
        {:error, "API error (#{status})"}

      {:error, reason} ->
        Logger.error("Groq API request failed: #{inspect(reason)}")
        {:error, "Request failed"}
    end
  end

  # ── SSE parsing ──────────────────────────────────────────────────────

  # Split buffer into complete lines + any trailing incomplete fragment.
  defp split_sse_buffer(buffer) do
    lines = String.split(buffer, "\n")

    case List.pop_at(lines, -1) do
      # Trailing element is always the incomplete fragment (possibly "")
      {remaining, complete} -> {complete, remaining}
    end
  end

  defp parse_sse_line("data: [DONE]"), do: :done

  defp parse_sse_line("data: " <> json) do
    case Jason.decode(json) do
      {:ok, %{"choices" => [%{"delta" => %{"content" => content}} | _]}}
      when is_binary(content) ->
        {:ok, content}

      _ ->
        :skip
    end
  end

  defp parse_sse_line(_), do: :skip
end
