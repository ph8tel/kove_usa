# Kove Moto USA — V2 Plan: Users, Persistence & LLM Tool Calling

> Written after a full review of the V1 codebase (March 2026).
> Covers the current state honestly, what must be fixed before V2 starts,
> the DB schema additions, and the tool-calling architecture.

---

## 1. Current State Audit

### What is solid

| Layer | Status |
|---|---|
| Supervision tree (GenServer → TaskSupervisor → Task) | ✅ Correct. GenServer never blocks; tasks are fire-and-forget. |
| `GroqBehaviour` + Mox in tests | ✅ Clean contract. Must be extended, not replaced, for V2. |
| SSE streaming pipeline | ✅ Buffer-based SSE parsing is correct. `into:` callback on `Req.post!` is the right approach. |
| Input sanitization + prompt security rules | ✅ Just added. Covers prompt injection, truncation, control chars. |
| pgvector extension | ✅ Installed, `descriptions.embedding vector(1536)` column exists. |
| `descriptions_without_embedding` query guard | ✅ Correctly excludes the vector column from all non-embedding queries. |

### What needs fixing before V2 starts

#### 1.1 Pseudo-RAG keyword matching is fragile

`Prompt.relevant_bikes/2` uses `String.contains?/2` on lowercased tokens. It misses:
- Synonyms ("adventure bike" vs "adv", "eight hundred" vs "800X")
- Partial number matches ("500" matching both "500X" and "1000 RR" if that existed)
- Any question that doesn't name a model ("what's your lightest bike?")

**Fix:** replace with a proper vector similarity search once embeddings are populated (see §2.1).
Until embeddings are ready, the keyword matching is acceptable as a placeholder but should not be built on further.

#### 1.2 No context window management ✅ Fixed

The entire `chat_history` list is serialised into every API call verbatim. `llama-3.3-70b-versatile` has a 128k-token context limit. A long session with detailed spec context in the system prompt can quietly approach this limit and then fail with a rate-limit/overflow error that surfaces as a generic error to the user.

**Fix:** add a `ContextBuilder` module before V2 that enforces a token budget:
- Approximate token count as `div(String.length(content), 4)` (conservative estimate)
- Always keep the system prompt
- Keep the most recent N messages that fit within a budget (e.g. 90k tokens)
- Summarise dropped history with a single "Earlier in this conversation…" message if desired

#### 1.3 `bikes_full` loaded at mount and held in socket assigns forever ✅ Fixed

`StorefrontLive.mount/3` calls `Bikes.list_bikes_full/0` (all associations, every bike) and stores it in the socket. It sits in LiveView assigns for the lifetime of the socket connection, consuming memory even when the user never opens the chat. With more bikes this grows linearly.

**Fix:** lazy-load `bikes_full` on first `{:chat_send, _}` event and cache it in assigns only after that point. A simple `@bikes_full_loaded` boolean assign tracks whether the fetch has happened.

#### 1.4 `Order` schema is a placeholder with no `user_id`

`orders` exists but has no foreign key to a user, no status lifecycle, and is wired to nothing. V2 needs a real order workflow.

#### 1.5 `descriptions.embedding` is never populated

The column exists but is always `nil`. The `descriptions_without_embedding` workaround in every query is a permanent band-aid unless the embeddings are generated.

---

## 2. Prerequisites — What to Build Before V2

### 2.1 Populate Embeddings (True RAG)

Groq has no embedding endpoint available. Uses OpenAI `text-embedding-3-small` at 768 dimensions (the `dimensions` parameter compresses the output from 1536 → 768, retaining quality while matching the current column size).

**Decision:** OpenAI `text-embedding-3-small` at 768 dims. The `vector(1536)` column was migrated to `vector(768)` via migration `20260309000002`.

Steps:
1. Add `OPENAI_API_KEY` to env and `runtime.exs`.
2. Create `Kove.KovyAssistant.Embeddings` module with `embed_text/1 :: {:ok, [float()]} | {:error, term()}`.
3. Write a Mix task `mix kove.embed_descriptions` that:
   - Fetches all descriptions where `embedding IS NULL`
   - Calls `Embeddings.embed_text/1` for each body
   - Updates the row with the returned vector
4. Replace `Prompt.relevant_bikes/2` with `Embeddings.search_descriptions/2` that:
   - Embeds the user query
   - Runs `SELECT bike_id FROM descriptions ORDER BY embedding <=> $1 LIMIT 5`
   - Returns the distinct bike_ids, which the prompt builder uses to select detailed context
5. Keep `Prompt.relevant_bikes/2` as a fallback when embeddings are unavailable (dev without API key, test env).

```
# New query in Kove.Bikes
def search_bikes_by_embedding(query_vector, limit \\ 4) do
  from(d in Description,
    order_by: cosine_distance(d.embedding, ^query_vector),
    limit: ^limit,
    select: d.bike_id,
    distinct: true
  )
  |> Repo.all()
end
```

### 2.2 Auth (phx.gen.auth)

Run `mix phx.gen.auth Accounts User users` with email/password. This generates:
- `users` and `user_tokens` tables
- `Kove.Accounts` context
- Registration, log-in, password reset LiveViews
- `fetch_current_user` plug and `on_mount` hook

**Important:** Keep the existing public routes (`/` and `/bikes/:slug`) outside any authenticated `live_session`. Only the user-specific routes (orders, garage, saved chats) require auth.

### 2.3 ContextBuilder Module

```
lib/kove/kovy_assistant/context_builder.ex
```

```elixir
defmodule Kove.KovyAssistant.ContextBuilder do
  @token_budget 90_000
  @approx_chars_per_token 4

  def trim_history(system_prompt, history) do
    budget = @token_budget - estimate_tokens(system_prompt)
    trim_to_budget(Enum.reverse(history), budget, [])
  end

  defp estimate_tokens(text), do: div(String.length(text), @approx_chars_per_token)
  ...
end
```

---

## 3. DB Plan — New Tables for V2

### 3.1 Extend `orders` — add user ownership and lifecycle

**Migration:** `alter table(:orders)`
```
add :user_id,             references(:users, on_delete: :nilify_all)
add :status,              :string, default: "pending", null: false
add :tracking_number,     :string
add :estimated_delivery,  :utc_datetime
add :shipped_at,          :utc_datetime
add :confirmed_at,        :utc_datetime
```

Status enum values: `:pending → :confirmed → :shipped → :delivered | :cancelled`

### 3.2 New: `user_bikes` — the user's garage

```
create table(:user_bikes) do
  add :user_id,       references(:users,  on_delete: :delete_all), null: false
  add :bike_id,       references(:bikes,  on_delete: :restrict),   null: false
  add :vin,           :string
  add :purchase_date, :date
  add :mileage_km,    :integer
  add :notes,         :text
  add :color,         :string
  timestamps()
end

create unique_index(:user_bikes, [:user_id, :vin])
create index(:user_bikes, [:user_id])
```

Schema: `Kove.UserBikes.UserBike` — `belongs_to :user`, `belongs_to :bike`
Context: `Kove.UserBikes` — `list_user_bikes/1`, `register_bike/2`, `update_bike/2`

### 3.3 New: `chat_sessions` + `chat_messages` — persistent history

```
create table(:chat_sessions) do
  add :user_id,     references(:users, on_delete: :delete_all), null: false
  add :bike_id,     references(:bikes, on_delete: :nilify_all)  # nil = catalog session
  add :title,       :string   # auto-generated from first message
  add :archived_at, :utc_datetime
  timestamps()
end

create index(:chat_sessions, [:user_id])

create table(:chat_messages) do
  add :session_id, references(:chat_sessions, on_delete: :delete_all), null: false
  add :role,       :string, null: false   # "user" | "assistant" | "tool"
  add :content,    :text,   null: false
  add :tool_name,  :string  # set when role = "tool"
  add :position,   :integer, null: false
  timestamps()
end

create index(:chat_messages, [:session_id, :position])
```

**Context:** `Kove.Chat` — `create_session/2`, `append_message/2`, `list_session_messages/1`, `list_user_sessions/1`

**LiveView integration:** on `{:chat_send, msg}`, the parent LiveView (if authenticated) calls `Chat.append_message/2` to persist. On mount, if a `session_id` param exists, load history from DB instead of starting empty. Anonymous users continue with ephemeral assigns as today.

---

## 4. Tool-Calling Architecture

### 4.1 How Groq Function Calling Works

The Groq API is OpenAI-compatible. Pass a `tools` array of JSON Schema specs alongside the messages. The model responds with either a normal message **or** a `tool_calls` array. You execute the tool locally, append the result as a `"tool"` role message, then re-call the API to get the final streamed answer.

```
User message
     │
     ▼
[Groq API — non-streaming, tools enabled]
     │
     ├── Normal response? ──► stream as today
     │
     └── tool_calls response?
              │
              ▼
        Dispatch each call to ToolRegistry
              │
              ▼
        Append tool results to messages
              │
              ▼
        [Groq API — streaming, no tools] ──► stream chunks to LiveView
```

The key: **only the first Groq call needs to support tools; the follow-up is plain streaming**. This minimises changes to the existing streaming pipeline.

### 4.2 New Behaviour: `GroqBehaviour` Extension

Add one callback to the existing behaviour (non-breaking — existing `GroqMock` just needs a new `stub`):

```elixir
@doc "Non-streaming call with tool specs. Returns {:ok, {:tool_calls, [map()]}} | {:ok, {:message, String.t()}} | {:error, ...}"
@callback chat_with_tools(messages :: [map()], tools :: [map()]) ::
  {:ok, {:tool_calls, [map()]}} | {:ok, {:message, String.t()}} | {:error, atom(), String.t()}
```

### 4.3 Tool Behaviour

```
lib/kove/kovy_assistant/tool.ex           ← behaviour definition
lib/kove/kovy_assistant/tool_registry.ex  ← discovers + dispatches tools
lib/kove/kovy_assistant/tools/
    get_order_status.ex
    recommend_parts.ex
    get_user_garage.ex
    get_service_schedule.ex
```

```elixir
defmodule Kove.KovyAssistant.Tool do
  @moduledoc "Behaviour every Kovy tool must implement."

  @doc "Returns the JSON Schema map sent to the LLM as part of the `tools` array."
  @callback spec() :: map()

  @doc """
  Executes the tool. `args` is the decoded JSON map from the LLM's tool_call.
  `context` carries runtime info (current_user, bike, etc.).
  Must return a plain-text string the LLM can read.
  """
  @callback execute(args :: map(), context :: map()) :: {:ok, String.t()} | {:error, String.t()}
end
```

### 4.4 ToolRegistry

```elixir
defmodule Kove.KovyAssistant.ToolRegistry do
  @tools [
    Kove.KovyAssistant.Tools.GetOrderStatus,
    Kove.KovyAssistant.Tools.RecommendParts,
    Kove.KovyAssistant.Tools.GetUserGarage,
    Kove.KovyAssistant.Tools.GetServiceSchedule
  ]

  def specs, do: Enum.map(@tools, & &1.spec())

  def dispatch(tool_name, args, context) do
    case Enum.find(@tools, &(&1.spec()["function"]["name"] == tool_name)) do
      nil  -> {:error, "Unknown tool: #{tool_name}"}
      mod  -> mod.execute(args, context)
    end
  end
end
```

**Adding a new tool in V2+:** create the module, add it to `@tools`. Nothing else changes.

### 4.5 Example Tool: `GetOrderStatus`

```elixir
defmodule Kove.KovyAssistant.Tools.GetOrderStatus do
  @behaviour Kove.KovyAssistant.Tool

  alias Kove.Orders

  @impl true
  def spec do
    %{
      "type" => "function",
      "function" => %{
        "name"        => "get_order_status",
        "description" => "Look up the status and shipping info for a customer order.",
        "parameters"  => %{
          "type"       => "object",
          "properties" => %{
            "order_id" => %{"type" => "integer", "description" => "The numeric order ID."}
          },
          "required"   => ["order_id"]
        }
      }
    }
  end

  @impl true
  def execute(%{"order_id" => order_id}, %{current_user: user}) do
    # Always scope to the authenticated user — never trust LLM-supplied IDs alone
    case Orders.get_user_order(user.id, order_id) do
      nil   -> {:ok, "No order ##{order_id} found for your account."}
      order -> {:ok, format_order(order)}
    end
  end

  def execute(_, _), do: {:error, "Missing order_id argument."}

  defp format_order(order) do
    """
    Order ##{order.id}: #{order.status}
    Bike: #{order.bike.name}
    Tracking: #{order.tracking_number || "not yet assigned"}
    Estimated delivery: #{order.estimated_delivery || "TBD"}
    """
  end
end
```

### 4.6 New KovyAssistant Cast Handler

```elixir
# New client API — context map carries user + optional bike
def send_message_v2(context, chat_history, caller_pid \\ self()) do
  GenServer.cast(__MODULE__, {:send_message_v2, context, chat_history, caller_pid})
end

# Handler
def handle_cast({:send_message_v2, context, chat_history, caller_pid}, state) do
  Task.Supervisor.start_child(Kove.TaskSupervisor, fn ->
    clean_history = InputSanitizer.sanitize_history(chat_history)
    system_prompt = Prompt.build_system_prompt_v2(context)
    messages      = build_api_messages(system_prompt, clean_history)
    tools         = ToolRegistry.specs()

    case groq_module().chat_with_tools(messages, tools) do
      {:ok, {:message, text}} ->
        # No tool call — stream the response directly
        # (Since we already have the full text here, send as a single chunk + done)
        send(caller_pid, {:kovy_chunk, text})
        send(caller_pid, {:kovy_done})

      {:ok, {:tool_calls, calls}} ->
        # Execute tools, append results, then stream final answer
        updated_messages = execute_tool_calls(calls, messages, context)
        stream_with_retry(updated_messages, caller_pid, 1)

      {:error, type, msg} ->
        send(caller_pid, {:kovy_error, type, msg})
    end
  end)
  {:noreply, state}
end
```

> **Note on streaming with tool calls:** The first API call (with tools) must be non-streaming because we need the full JSON to parse `tool_calls`. The subsequent "compose answer" call can and should stream normally. The LiveView sees the same `{:kovy_chunk, text}` / `{:kovy_done}` messages — no changes needed to `ChatLive` or the `handle_info` callbacks in the parent LiveViews.

---

## 5. V2 Implementation Order

Doing these out of order creates rework. Suggested sequence:

```
Phase 0 — Foundation fixes (do before anything else)
  [x] ContextBuilder — token budget trimming
  [x] Lazy-load bikes_full in StorefrontLive
  [x] Rate limiting — IP-based, two tiers (public/authenticated)
  [x] Populate embeddings (Mix task + OpenAI embed API) — run `mix kove.embed_descriptions` after adding OPENAI_API_KEY to .env
  [x] Replace keyword matching with vector search

Phase 1 — Auth & User model
  [ ] mix phx.gen.auth Accounts User users
  [ ] Add user_id to existing Order schema + status lifecycle
  [ ] UserBikes schema + migration + context
  [ ] Wire current_user into KovyAssistant context map

Phase 2 — Chat persistence
  [ ] chat_sessions + chat_messages migrations + schemas
  [ ] Kove.Chat context (CRUD)
  [ ] StorefrontLive + BikeDetailsLive: persist/load history when authenticated
  [ ] Session list page for authenticated users

Phase 3 — LLM Tool Calling
  [ ] Extend GroqBehaviour with chat_with_tools/2
  [ ] Implement Groq.chat_with_tools/2
  [ ] Tool behaviour + ToolRegistry
  [ ] GetOrderStatus tool (+ Orders context update)
  [ ] RecommendParts tool
  [ ] GetUserGarage tool
  [ ] KovyAssistant.send_message_v2/3 handler
  [ ] Update Mox mock for new callback
  [ ] Tests for each tool module

Phase 4 — UX
  [ ] Account pages (garage management, order history)
  [ ] Chat session history sidebar
  [ ] "Kovy knows your bikes" personalised quick-asks
```

---

## 6. Open Questions to Decide Early

1. **Embedding provider:** Groq (free, `nomic-embed-text-v1.5`, 768-dim → need schema migration) vs OpenAI (`text-embedding-3-small`, 1536-dim → fits existing column). Recommend OpenAI to avoid the migration.

2. **Session auto-title:** Generate a session title from the first user message using a cheap sync Groq call, or just use the first 60 characters of the message? The sync call is cleaner UX but adds latency.

3. **Anonymous chat persistence:** Should we persist anonymous sessions keyed by a browser cookie/fingerprint, then merge them on sign-up? Common pattern but adds complexity. Simpler option: don't persist anonymous sessions, show a "sign in to save your chat history" nudge.

4. **Tool call streaming UX:** When Kovy is executing a tool, the user sees the loading spinner but nothing else. Consider sending a `{:kovy_status, "Looking up your order…"}` message type so the UI can show "Checking order status…" text while the tool runs.

5. **`recommend_parts` data source:** Does a real parts catalog exist, or is this the LLM generating recommendations from training data plus bike context? If the latter, the "tool" is really just a prompt augmentation and doesn't need to be a tool call — it can just be a section in the system prompt. A real tool is only warranted when there's a live data source to query.
