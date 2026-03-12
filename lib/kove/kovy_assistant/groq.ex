defmodule Kove.KovyAssistant.Groq do
  @moduledoc """
  HTTP client for the Groq chat‑completion API.

  Supports both synchronous and streaming modes.  In streaming mode,
  SSE chunks are parsed and forwarded to a caller PID as messages:

    * `{:kovy_chunk, text}`  — a token fragment
    * `{:kovy_done}`         — stream finished
    * `{:kovy_error, error_type, message}` — categorized error occurred
  """

  @behaviour Kove.KovyAssistant.GroqBehaviour

  require Logger

  alias Kove.KovyAssistant.GroqError

  @default_model "llama-3.3-70b-versatile"

  # Reads the base URL at runtime so the mock server URL can be injected
  # via the GROQ_BASE_URL environment variable during testing.
  defp groq_chat_url do
    base = Application.get_env(:kove, :groq_base_url, "https://api.groq.com")
    base <> "/openai/v1/chat/completions"
  end

  defp api_key do
    Application.get_env(:kove, :groq_api_key) || System.get_env("GROQ_API_KEY")
  end

  @doc "Returns true if the Groq API key is available."
  @impl true
  def api_key_available?, do: api_key() != nil

  # ── Public API ───────────────────────────────────────────────────────

  @doc """
  Streams a chat completion from Groq.

  Sends `{:kovy_chunk, text}`, `{:kovy_done}`, or `{:kovy_error, error_type, message}`
  messages to `caller_pid`.
  """
  @impl true
  def stream_chat(messages, caller_pid) do
    case api_key() do
      nil ->
        send(
          caller_pid,
          {:kovy_error, :auth_failed,
           "GROQ_API_KEY not configured. Set the environment variable and restart."}
        )

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
    request_id = generate_request_id()

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

    Logger.info("Groq stream START",
      request_id: request_id,
      message_count: length(messages),
      caller: inspect(caller_pid)
    )

    # We buffer partial SSE lines across chunks in the process dictionary.
    Process.put(:sse_buffer, "")
    Process.put(:sse_chunk_count, 0)

    try do
      resp =
        Req.post!(groq_chat_url(),
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

      if resp.status == 200 do
        Logger.info("Groq stream SUCCESS",
          request_id: request_id,
          chunks_received: chunk_count
        )

        send(caller_pid, {:kovy_done})
      else
        # Non-200: the into callback received error JSON, not SSE.
        # Categorize and send structured error.
        error = GroqError.from_http_response(resp.status, resp.body)

        Logger.error("Groq stream FAILED",
          request_id: request_id,
          error_type: error.type,
          status: error.status,
          message: error.message
        )

        send(caller_pid, {:kovy_error, error.type, GroqError.message(error)})
      end

      :ok
    rescue
      e ->
        Logger.error("Groq stream CRASHED",
          request_id: request_id,
          error: Exception.message(e),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        send(
          caller_pid,
          {:kovy_error, :internal_error,
           GroqError.message(%GroqError{type: :internal_error, message: Exception.message(e)})}
        )

        :error
    end
  end

  # ── Synchronous ──────────────────────────────────────────────────────

  defp do_sync(messages, api_key) do
    request_id = generate_request_id()

    Logger.info("Groq sync START",
      request_id: request_id,
      message_count: length(messages)
    )

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

    case Req.post(groq_chat_url(), headers: headers, body: body) do
      {:ok, %{status: 200, body: body}} ->
        content = get_in(body, ["choices", Access.at(0), "message", "content"])

        Logger.info("Groq sync SUCCESS",
          request_id: request_id,
          content_length: byte_size(content || "")
        )

        {:ok, content || ""}

      {:ok, %{status: status, body: body}} ->
        error = GroqError.from_http_response(status, body)

        Logger.error("Groq sync FAILED",
          request_id: request_id,
          error_type: error.type,
          status: status,
          message: error.message
        )

        {:error, error.type, GroqError.message(error)}

      {:error, reason} ->
        Logger.error("Groq sync request FAILED",
          request_id: request_id,
          error: inspect(reason)
        )

        {:error, :connection,
         GroqError.message(%GroqError{type: :connection, message: inspect(reason)})}
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

  # Generate a unique request ID for logging/tracing
  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
