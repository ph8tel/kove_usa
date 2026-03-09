defmodule Kove.KovyAssistant.RateLimiter do
  @moduledoc """
  In-memory, ETS-backed rate limiter for Kovy chat requests.

  Uses a **fixed tumbling window** algorithm. Each rate-limit key is tracked
  as an ETS entry `{{key, window_id}, count}` where `window_id` is the
  current time divided by the window duration. When the window rolls over the
  old entry is simply replaced, so no per-key cleanup is needed on each check.

  A supervised GenServer owns the ETS table and runs a periodic sweep every
  5 minutes to remove entries from past windows, preventing unbounded growth
  in tables with many distinct keys.

  ## Tiers

  | Tier            | Limit | Window   | Notes                              |
  |-----------------|-------|----------|------------------------------------|
  | `:public`       | 20    | 1 minute | Per client IP address              |
  | `:authenticated`| 60    | 1 minute | Per user ID (not yet used in V1)   |

  ## Usage

      case RateLimiter.check_and_increment({:ip, "1.2.3.4"}, :public) do
        :ok ->
          # dispatch to Groq
        {:error, :rate_limited, retry_after_s} ->
          # send error to caller
      end

  ## Key formats

  - `{:ip, "1.2.3.4"}` — anonymous public visitor keyed by remote IP
  - `{:user, user_id}` — authenticated user keyed by DB id (V2)
  """

  use GenServer

  require Logger

  @table :kovy_rate_limits

  # ── Tier configuration ───────────────────────────────────────────────

  # {limit, window_ms}
  @tiers %{
    public: {20, 60_000},
    authenticated: {60, 60_000}
  }

  # The longest window duration — used to determine the minimum safe window_id
  # to keep during cleanup.
  @max_window_ms 60_000

  # ── Supervision ──────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()
    {:ok, %{}}
  end

  # ── Public API ───────────────────────────────────────────────────────

  @doc """
  Atomically increments the request count for `key` in the current window
  and checks it against the tier limit.

  Returns `:ok` if the request is allowed, or
  `{:error, :rate_limited, retry_after_seconds}` if the limit is exceeded.

  Returns `:ok` immediately if rate limiting is disabled via config
  (`config :kove, :rate_limiter_enabled, false`) — this is set in test env
  to prevent test connections sharing 127.0.0.1 from tripping each other.

  This function is called directly from Task processes (not via GenServer
  call), so it must be safe for concurrent access. The ETS
  `update_counter/4` operation is atomic, so each caller receives a unique
  monotonically increasing count with no race condition.
  """
  @spec check_and_increment(term(), :public | :authenticated) ::
          :ok | {:error, :rate_limited, non_neg_integer()}
  def check_and_increment(key, tier \\ :public) do
    if enabled?() do
      do_check_and_increment(key, tier)
    else
      :ok
    end
  end

  @doc """
  Returns `true` if rate limiting is available (table exists).
  Used in tests to check initialisation.
  """
  def available? do
    :ets.whereis(@table) != :undefined
  end

  # ── GenServer callbacks ──────────────────────────────────────────────

  @impl true
  def handle_info(:cleanup, state) do
    now_ms = System.monotonic_time(:millisecond)
    # Keep current window and one prior window for the longest tier.
    # Entries from windows older than that are safe to delete.
    min_window_id = div(now_ms, @max_window_ms) - 2

    deleted =
      :ets.select_delete(@table, [
        {{{:_, :"$1"}, :_}, [{:<, :"$1", min_window_id}], [true]}
      ])

    if deleted > 0 do
      Logger.debug("RateLimiter: cleaned up stale ETS entries", count: deleted)
    end

    schedule_cleanup()
    {:noreply, state}
  end

  # ── Private helpers ──────────────────────────────────────────────────

  defp do_check_and_increment(key, tier) do
    {limit, window_ms} = tier_config(tier)
    now_ms = System.monotonic_time(:millisecond)
    window_id = div(now_ms, window_ms)
    ets_key = {key, window_id}

    # update_counter/4 atomically creates the entry with default value 0 if
    # it doesn't exist, then applies the increment operation {2, 1} (position 2,
    # delta +1). Returns the new count.
    count = :ets.update_counter(@table, ets_key, {2, 1}, {ets_key, 0})

    if count > limit do
      window_ends_ms = (window_id + 1) * window_ms
      retry_after_s = max(1, ceil((window_ends_ms - now_ms) / 1_000))

      Logger.warning("RateLimiter: limit exceeded",
        key: inspect(key),
        tier: tier,
        count: count,
        limit: limit,
        retry_after_s: retry_after_s
      )

      {:error, :rate_limited, retry_after_s}
    else
      :ok
    end
  end

  defp enabled? do
    Application.get_env(:kove, :rate_limiter_enabled, true)
  end

  defp tier_config(tier) do
    Map.get(@tiers, tier, @tiers.public)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 5 * 60_000)
  end
end
