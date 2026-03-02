# Kove Moto USA

A Phoenix LiveView application for the Kove Moto USA motorcycle catalog with **Kovy**, an AI-powered bike assistant that answers technical questions grounded in real spec data.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Elixir 1.17 / Erlang/OTP 27 |
| Web | Phoenix 1.8, LiveView 1.1 |
| Database | PostgreSQL + pgvector |
| CSS | Tailwind CSS 4.1, daisyUI 5 |
| AI | Groq API (`llama-3.3-70b-versatile`), SSE streaming |
| HTTP Client | Req ~> 0.5 |
| Testing | ExUnit, Mox (for Groq client) |

## Quick Start

```bash
# 1. Copy env file and add your Groq API key
cp .env.example .env
# edit .env → set GROQ_API_KEY

# 2. Start Postgres (docker-compose provided)
docker compose up -d

# 3. Install deps, create DB, run migrations, seed data
cd kove
mix setup

# 4. Start the server (sources .env automatically via runtime.exs)
source ../.env && mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

## Routes

| Path | LiveView | Description |
|------|----------|-------------|
| `/` | `StorefrontLive` | 2×3 grid of bike cards with hero images, prices, categories |
| `/bikes/:slug` | `BikeDetailsLive` | Full spec page with tabs + Kovy AI chat panel |

## Project Structure

```
kove/
├── lib/
│   ├── kove/
│   │   ├── application.ex          # OTP app — supervises Repo, TaskSupervisor, KovyAssistant, Endpoint
│   │   ├── repo.ex                 # Ecto Repo
│   │   ├── bikes.ex                # Bikes context (list_bikes, get_bike_by_slug, hero_image_url, format_msrp)
│   │   ├── bikes/bike.ex           # Bike schema
│   │   ├── engines/engine.ex       # Engine schema (1:1 with bike)
│   │   ├── chassis_specs/          # ChassisSpec schema (1:1 with bike)
│   │   ├── dimensions/             # Dimension schema (1:1 with bike)
│   │   ├── bike_features/          # BikeFeature schema (1:many with bike)
│   │   ├── images/                 # Image schema (1:many with bike)
│   │   ├── descriptions/           # Description schema (1:many, has pgvector embedding column)
│   │   ├── orders/                 # Order schema
│   │   ├── kovy_assistant.ex       # GenServer — dispatches chat requests to TaskSupervisor → Groq
│   │   └── kovy_assistant/
│   │       ├── prompt.ex           # Builds structured system prompts from full bike data
│   │       ├── groq.ex             # Groq API client — streaming SSE + sync modes
│   │       └── groq_behaviour.ex   # Behaviour for Mox testing
│   └── kove_web/
│       ├── router.ex               # / → StorefrontLive, /bikes/:slug → BikeDetailsLive
│       ├── live/
│       │   ├── storefront_live.ex  # Bike catalog grid
│       │   └── bike_details_live.ex# Spec tabs (Marketing/Engine/Chassis) + streaming Kovy chat
│       ├── components/             # CoreComponents, Layouts
│       ├── controllers/            # ErrorHTML, ErrorJSON
│       └── endpoint.ex
├── test/
│   ├── kove/
│   │   ├── bikes/                  # Bike schema tests
│   │   ├── engines/                # Engine schema tests
│   │   ├── chassis_specs/          # ChassisSpec schema tests
│   │   ├── dimensions/             # Dimension schema tests
│   │   ├── bike_features/          # BikeFeature schema tests
│   │   ├── images/                 # Image schema tests
│   │   ├── descriptions/           # Description schema tests
│   │   ├── orders/                 # Order schema tests
│   │   ├── kovy_assistant_test.exs # GenServer integration tests (Mox)
│   │   └── kovy_assistant/
│   │       ├── prompt_test.exs     # Prompt builder unit tests
│   │       └── groq_test.exs       # Groq client unit tests (nil-key paths)
│   ├── kove_web/live/
│   │   ├── storefront_live_test.exs
│   │   └── bike_details_live_chat_test.exs  # Chat UI + streaming callback tests (Mox)
│   └── support/
│       ├── conn_case.ex
│       └── data_case.ex
├── priv/repo/
│   ├── migrations/                 # 9 migrations (pgvector, engines, bikes, chassis, dims, features, images, descriptions, orders)
│   └── seeds.exs                   # Seeds 6 bikes, 4 engines, full spec data
├── config/
│   ├── config.exs                  # Base config
│   ├── dev.exs                     # Dev DB config
│   ├── test.exs                    # Test DB + Mox groq_module config
│   ├── prod.exs                    # Prod config
│   └── runtime.exs                 # GROQ_API_KEY from env or ../.env file
└── assets/
    └── js/app.js                   # ScrollBottom hook for chat auto-scroll
```

## Kovy Assistant Architecture

```
BikeDetailsLive (LiveView)
  │ handle_event("send_message")
  ▼
KovyAssistant (GenServer)
  │ GenServer.cast → Task.Supervisor.start_child
  ▼
Task (async)
  ├── Prompt.build_system_prompt(bike)  ← serialises all bike data
  └── Groq.stream_chat(messages, caller_pid)
        │
        ▼  SSE chunks from Groq API
        send(caller_pid, {:kovy_chunk, text})
        send(caller_pid, {:kovy_done})
        │
        ▼
BikeDetailsLive.handle_info
  └── Updates chat_messages assigns → LiveView re-renders
```

The Groq module is swappable via `config :kove, :groq_module` — defaults to `Kove.KovyAssistant.Groq` in dev/prod, replaced by `Kove.KovyAssistant.GroqMock` (Mox) in tests.

## Database Schema

```
engines (1) ──────< bikes (1) ──────< chassis_specs
                       │ ──────< dimensions
                       │ ──────< bike_features
                       │ ──────< images
                       │ ──────< descriptions (has pgvector embedding column)
                       └──────< orders
```

Six bikes seeded: 800X Rally, 800X Pro, 800X Adventure, 450 Rally, MX 250F, MX 450F across 4 engine platforms.

## Testing

```bash
# Run all 90 tests
mix test

# Run only the new chat/assistant tests
mix test test/kove/kovy_assistant/ test/kove/kovy_assistant_test.exs test/kove_web/live/bike_details_live_chat_test.exs

# Pre-commit checks (compile warnings, format, tests)
mix precommit
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GROQ_API_KEY` | Yes (for chat) | Groq API key — `runtime.exs` also auto-reads `../.env` as fallback |
| `DATABASE_URL` | Prod only | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Prod only | Phoenix secret |

## What's Next (from PLAN.md)

- [ ] Semantic search over descriptions using pgvector embeddings
- [ ] Order capture form on bike detail page
- [ ] Admin page for viewing orders
- [ ] User auth + owned bikes dashboard
- [ ] RAG pipeline for maintenance docs
- [ ] Comparison UI ("Compare to KTM 450")
