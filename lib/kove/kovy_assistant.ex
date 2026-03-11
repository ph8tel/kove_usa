defmodule Kove.KovyAssistant do
  @moduledoc """
  GenServer that manages Kovy chat sessions.

  Receives chat requests from LiveViews, builds structured prompts with
  full bike context, and streams Groq responses back to the caller.

  Spawned tasks wrap streaming calls with error handling and retry logic
  for transient failures.
  """

  use GenServer

  alias Kove.KovyAssistant.Prompt
  alias Kove.KovyAssistant.InputSanitizer
  alias Kove.KovyAssistant.ContextBuilder
  alias Kove.KovyAssistant.RateLimiter
  alias Kove.KovyAssistant.Embeddings
  alias Kove.KovyAssistant.GroqError

  require Logger

  @max_retries 3
  @retry_backoff_base_ms 1000

  defp groq_module do
    Application.get_env(:kove, :groq_module, Kove.KovyAssistant.Groq)
  end

  # ── Client API ───────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Sends a chat message for `bike` with the given `chat_history`.

  `chat_history` should be a list of `%{role: :user | :assistant, content: ...}` maps
  representing the conversation so far (including the latest user message).

  `context` is an optional map with:
    * `:tier`            — `:public` (default) or `:authenticated`
    * `:rate_limit_key`  — `{:ip, "1.2.3.4"}` or `{:user, user_id}` (omit to skip rate limiting)
    * `:rider_mods`      — list of `UserBikeMod` structs for the owner's modifications

  Response tokens are streamed back to `caller_pid` (defaults to `self()`) as:

    * `{:kovy_chunk, text}`
    * `{:kovy_done}`
    * `{:kovy_error, reason}`
  """
  def send_message(bike, chat_history, caller_pid \\ self(), context \\ %{}) do
    GenServer.cast(__MODULE__, {:send_message, bike, chat_history, caller_pid, context})
  end

  @doc """
  Sends a catalog‑wide chat message with context for all `bikes`.

  Uses pseudo‑RAG: the latest user message is scanned for bike name / category
  keywords, and only matching bikes get their full specs serialised into the prompt.
  A compact catalog summary is always included.

  `context` is an optional map with:
    * `:tier`            — `:public` (default) or `:authenticated`
    * `:rate_limit_key`  — `{:ip, "1.2.3.4"}` or `{:user, user_id}` (omit to skip rate limiting)

  Streaming response messages are identical to `send_message/4`.
  """
  def send_catalog_message(bikes, chat_history, caller_pid \\ self(), context \\ %{}) do
    GenServer.cast(__MODULE__, {:send_catalog_message, bikes, chat_history, caller_pid, context})
  end

  # ── Server callbacks ─────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:send_message, bike, chat_history, caller_pid, context}, state) do
    tier = Map.get(context, :tier, :public)
    rate_limit_key = Map.get(context, :rate_limit_key)
    rider_mods = Map.get(context, :rider_mods, [])
    user_orders = Map.get(context, :user_orders, [])

    Logger.info("KovyAssistant: starting chat for bike",
      bike: bike.name,
      history_length: length(chat_history),
      tier: tier,
      rider_mods_count: length(rider_mods),
      caller: inspect(caller_pid)
    )

    with :ok <- check_rate_limit(rate_limit_key, tier, caller_pid) do
      Task.Supervisor.start_child(Kove.TaskSupervisor, fn ->
        try do
          groq = groq_module()
          Logger.info("KovyAssistant task: building prompt", bike: bike.name)

          clean_history =
            chat_history
            |> InputSanitizer.sanitize_history()
            |> ContextBuilder.trim_history(tier)

          system_prompt = Prompt.build_system_prompt(bike, rider_mods, user_orders)

          api_messages =
            [
              %{"role" => "system", "content" => system_prompt}
              | Enum.map(clean_history, fn msg ->
                  %{"role" => to_string(msg.role), "content" => msg.content}
                end)
            ]

          Logger.info("KovyAssistant task: streaming to Groq",
            bike: bike.name,
            message_count: length(api_messages),
            api_key_configured: groq.api_key_available?()
          )

          stream_with_retry(api_messages, caller_pid, 1)
        rescue
          e ->
            Logger.error("KovyAssistant task crashed",
              bike: bike.name,
              error: Exception.message(e),
              stacktrace: Exception.format_stacktrace(__STACKTRACE__)
            )

            send(
              caller_pid,
              {:kovy_error, :internal_error,
               GroqError.message(%GroqError{type: :internal_error, message: Exception.message(e)})}
            )
        end
      end)
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_catalog_message, bikes, chat_history, caller_pid, context}, state) do
    tier = Map.get(context, :tier, :public)
    rate_limit_key = Map.get(context, :rate_limit_key)

    Logger.info("KovyAssistant: starting catalog chat",
      bike_count: length(bikes),
      history_length: length(chat_history),
      tier: tier,
      caller: inspect(caller_pid)
    )

    with :ok <- check_rate_limit(rate_limit_key, tier, caller_pid) do
      Task.Supervisor.start_child(Kove.TaskSupervisor, fn ->
        try do
          groq = groq_module()

          clean_history =
            chat_history
            |> InputSanitizer.sanitize_history()
            |> ContextBuilder.trim_history(tier)

          # Extract latest user message for keyword matching (pseudo-RAG).
          # Use the sanitized query variant — no injection patterns, length-bounded.
          last_user_message =
            clean_history
            |> Enum.reverse()
            |> Enum.find(fn msg -> msg.role == :user end)
            |> case do
              nil -> ""
              msg -> InputSanitizer.sanitize_query(msg.content)
            end

          # Vector similarity search — finds bikes whose descriptions are
          # semantically closest to the user query. Falls back to keyword
          # matching inside build_catalog_system_prompt when embeddings are
          # unavailable (no API key, not yet populated, or transient error).
          relevant_ids =
            case Embeddings.find_relevant_bike_ids(last_user_message) do
              {:ok, ids} when ids != [] ->
                Logger.info("KovyAssistant: embedding search matched #{length(ids)} bike(s)")
                ids

              {:ok, []} ->
                Logger.info("KovyAssistant: embedding search empty, using keyword fallback")
                nil

              {:error, :no_api_key} ->
                nil

              {:error, kind, msg} ->
                Logger.warning(
                  "KovyAssistant: embedding search failed (#{kind}: #{msg}), using keyword fallback"
                )

                nil

              {:error, kind} ->
                Logger.warning(
                  "KovyAssistant: embedding search failed (#{kind}), using keyword fallback"
                )

                nil
            end

          system_prompt =
            Prompt.build_catalog_system_prompt(bikes, last_user_message, relevant_ids)

          api_messages =
            [
              %{"role" => "system", "content" => system_prompt}
              | Enum.map(clean_history, fn msg ->
                  %{"role" => to_string(msg.role), "content" => msg.content}
                end)
            ]

          Logger.info("KovyAssistant task: streaming catalog to Groq",
            message_count: length(api_messages),
            api_key_configured: groq.api_key_available?()
          )

          stream_with_retry(api_messages, caller_pid, 1)
        rescue
          e ->
            Logger.error("KovyAssistant catalog task crashed",
              error: Exception.message(e),
              stacktrace: Exception.format_stacktrace(__STACKTRACE__)
            )

            send(
              caller_pid,
              {:kovy_error, :internal_error,
               GroqError.message(%GroqError{type: :internal_error, message: Exception.message(e)})}
            )
        end
      end)
    end

    {:noreply, state}
  end

  # ── Rate limiting ────────────────────────────────────────────────────

  # If no rate_limit_key is provided, skip the check entirely.
  defp check_rate_limit(nil, _tier, _caller_pid), do: :ok

  defp check_rate_limit(rate_limit_key, tier, caller_pid) do
    case RateLimiter.check_and_increment(rate_limit_key, tier) do
      :ok ->
        :ok

      {:error, :rate_limited, retry_after_s} ->
        message =
          GroqError.message(%GroqError{
            type: :rate_limited,
            message: "Too many requests. Please wait #{retry_after_s} seconds and try again."
          })

        send(caller_pid, {:kovy_error, :rate_limited, message})
        :error
    end
  end

  # ── Retry logic ──────────────────────────────────────────────────────

  # Stream with exponential backoff retry for transient failures
  defp stream_with_retry(messages, caller_pid, attempt) when attempt <= @max_retries do
    groq = groq_module()

    case groq.stream_chat(messages, caller_pid) do
      :ok ->
        :ok

      :error when attempt < @max_retries ->
        backoff_ms = Integer.pow(2, attempt) * @retry_backoff_base_ms

        Logger.info("Groq stream failed, retrying",
          attempt: attempt,
          max_retries: @max_retries,
          backoff_ms: backoff_ms
        )

        Process.sleep(backoff_ms)
        stream_with_retry(messages, caller_pid, attempt + 1)

      :error ->
        Logger.error("Groq stream failed after retries",
          attempts: attempt,
          max_retries: @max_retries
        )

        send(
          caller_pid,
          {:kovy_error, :retry_exhausted,
           GroqError.message(%GroqError{type: :retry_exhausted, message: ""})}
        )

        :error
    end
  end
end
