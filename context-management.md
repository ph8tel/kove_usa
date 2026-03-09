
ContextBuilder (context_builder.ex)
Two tiers enforced on every Groq call:

Tier	Max messages	History token budget
:public	20	24 000 tokens
:authenticated	50	72 000 tokens
Walks history newest-first, accumulating messages until budget or count is exhausted. Also drops any dangling assistant turn at the start of the trimmed window (clean exchange pairs). Token estimate uses ceil(byte_size / 3) — intentionally conservative. V2 only needs to change the tier passed in when a user logs in.

RateLimiter (rate_limiter.ex)
ETS-backed, zero-dependency, supervised GenServer. Uses a composite key {rate_limit_key, window_id} with :ets.update_counter/4 — this is fully atomic with no race conditions. Periodic 5-minute cleanup prevents unbounded table growth.

Tier	Limit	Window
:public	20 req	60 sec
:authenticated	60 req	60 sec

Disabled in test env via config :kove, :rate_limiter_enabled, false so tests sharing 127.0.0.1 don't interfere with each other.

KovyAssistant — context propagation
send_message/4 and send_catalog_message/4 now accept an optional context map (backward-compatible — existing 3-arg test calls still work). The context carries tier: and rate_limit_key:. Rate limit check happens in handle_cast before the task is spawned, so an over-limit request never touches Groq.

Endpoint — peer data
:peer_data added to websocket and longpoll connect_info so both LiveViews can read the real client IP. V2 swaps tier: :public → :authenticated and rate_limit_key: {:ip, ip} → {:user, user_id}