# Kove Moto USA

> ## TODO
>
> - [ ] **True vector RAG** — Populate the existing `descriptions.embedding` column (`vector(768)`) via OpenAI's `/v1/embeddings` endpoint using Req. Swap the keyword-based `Prompt.relevant_bikes/2` for a pgvector cosine similarity query against `descriptions` to retrieve the most relevant chunks per user message.
> - [ ] **Rider-type survey in chat** — Extend the catalog chat (Kovy on the storefront) with a structured conversational survey: ask about riding experience, terrain, intended use, and budget, then recommend a specific model. The system prompt already primes Kovy for this flow — next step is adding structured state tracking (survey stage, answers collected) in the LiveView assigns so the UI can show progress and the final recommendation card.
> - [ ] **Embedding generation Mix task** — `mix kove.generate_embeddings` to batch-process all `descriptions` rows, call OpenAI embeddings API, and upsert the `embedding` column. Include rate limiting and progress output.
> - [ ] **Semantic search API** — Add `Bikes.search_descriptions(query, opts)` that embeds the query string and runs a pgvector nearest-neighbor search, returning ranked description + bike pairs.
> - [ ] **Mod embedding population** — Populate `user_bike_mods.embedding` (vector 768) for semantic search across rider modifications.
> - [ ] **Chat persistence** — `chat_sessions` + `chat_messages` tables for persistent conversation history.
> - [ ] **LLM tool calling** — Groq function calling with `ToolRegistry` for order status, parts recommendations, etc.

A Phoenix LiveView application for the Kove Moto USA motorcycle catalog with **Kovy**, an AI-powered bike assistant that answers technical questions grounded in real spec data. Deployed on **Fly.io** at [kove.fly.dev](https://kove.fly.dev).

## Features

### Public
- **Storefront** (`/`) — 2×3 bike grid with catalog-wide Kovy chat for lineup questions and model comparisons
- **Bike detail pages** (`/bikes/:slug`) — Full spec tabs (Marketing, Engine, Chassis) with single-bike Kovy chat
- **Shared chat UI** (`KoveWeb.ChatLive`) — Desktop sticky sidebar + mobile FAB/full-screen drawer
- **Pseudo-RAG prompt narrowing** — `Prompt.relevant_bikes/2` keyword matching for efficient context windowing

### Authenticated (My Garage)
- **My Garage** (`/home`) — Rider dashboard requiring authentication
- **Image carousel** — User-uploaded bike photos stored on Cloudflare R2, displayed in an auto-playing slideshow
- **My Mods** tab — Track rider modifications (11 categories: exhaust, gearing, suspension, clutch, engine, electronics, intake, controls, tires, protection, lighting) with dollar cost and clickable 5-star rating
- **Photos** tab — Upload/manage bike photos via form-based R2 uploads with preview
- **Maintenance tab** — Engine-compatible oil change kit cards with one-click add-to-cart
- **Orders tab** — Cart review, item removal, checkout flow, and order history/status timeline
- **Order-aware Kovy chat** — AI assistant sees the rider's specific bike, modifications, and non-cart orders; quick ask includes **"My order status?"** when orders exist

### Auth
- **Email/password registration and login** via `phx.gen.auth`
- **Magic-link login** — one-click email authentication
- **Google OAuth login/registration** — `Continue with Google` on both login and registration screens
- **Public privacy policy** — required for Google OAuth app publishing, available at `/privacy-policy`
- **Session management** — settings, email change, password change

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Elixir 1.17 / Erlang/OTP 27 |
| Web | Phoenix 1.8, LiveView 1.1 |
| Database | PostgreSQL + pgvector (Neon in prod) |
| CSS | Tailwind CSS 4.1, daisyUI 5 |
| AI | Groq API (`llama-3.3-70b-versatile`), SSE streaming |
| Embeddings | OpenAI `text-embedding-3-small` (768 dims) |
| Object Storage | Cloudflare R2 (AWS Sig V4) |
| HTTP Client | Req ~> 0.5 |
| Auth | `phx.gen.auth` (bcrypt, magic link, sessions) |
| Testing | ExUnit (379 tests), Mox (for Groq client) |
| Deployment | Fly.io |

## Quick Start

```bash
# 1. Copy env file and add your API keys
cp .env.example .env
# edit .env → set GROQ_API_KEY, OPENAI_API_KEY, R2_* vars, GOOGLE_OAUTH_* vars

# 2. Start Postgres (docker-compose provided)
docker compose up -d

# 3. Install deps, create DB, run migrations, seed data
mix setup

# 4. Start the server (sources .env automatically via runtime.exs)
source ../.env && mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

## Routes

| Path | LiveView | Auth | Description |
|------|----------|------|-------------|
| `/` | `StorefrontLive` | Public | 2×3 bike grid + catalog-wide Kovy chat |
| `/bikes/:slug` | `BikeDetailsLive` | Public | Full spec page with tabs + single-bike Kovy chat |
| `/home` | `UserHomeLive` | **Required** | My Garage: carousel, mods, photos, maintenance kits, orders, Kovy chat |
| `/users/register` | `UserLive.Registration` | Public | Email/password registration |
| `/users/log-in` | `UserLive.Login` | Public | Email/password login |
| `/users/log-in/:token` | `UserLive.Confirmation` | Public | Magic-link confirmation |
| `/users/settings` | `UserLive.Settings` | **Required** | Email/password settings |
| `/privacy-policy` | `PageController.privacy` | Public | Privacy statement for Google OAuth verification and public users |

Controller auth routes:

| Path | Controller | Auth | Description |
|------|------------|------|-------------|
| `/auth/google` | `GoogleAuthController.request` | Public | Starts Google OAuth flow (state + redirect) |
| `/auth/google/callback` | `GoogleAuthController.callback` | Public | Handles OAuth callback, links/creates user, logs in |

## Project Structure

```
lib/kove/
├── accounts.ex                     # Accounts context (auth, users, tokens)
├── accounts/
│   ├── google_oauth.ex             # Google OAuth client (authorize URL, token exchange, userinfo)
│   ├── scope.ex                    # Kove.Accounts.Scope
│   ├── user.ex                     # User schema
│   ├── user_notifier.ex            # Email notifications (magic link, etc.)
│   └── user_token.ex               # Session/magic-link tokens
├── bikes.ex                        # Bikes context (list, get, format helpers)
├── bikes/bike.ex                   # Bike schema (belongs_to :engine)
├── engines/engine.ex               # Engine schema (1:1 with bike)
├── chassis_specs/chassis_spec.ex   # ChassisSpec schema (1:1 with bike)
├── dimensions/dimension.ex         # Dimension schema (1:1 with bike)
├── bike_features/bike_feature.ex   # BikeFeature schema (1:many with bike)
├── images/image.ex                 # Image schema (1:many with bike)
├── descriptions/description.ex     # Description schema (1:many, has pgvector embedding)
├── orders.ex                       # Orders context (cart, checkout, order history)
├── orders/
│   ├── order.ex                    # Order schema
│   └── order_item.ex               # OrderItem schema
├── parts.ex                        # Parts context (kit lookup + compatibility)
├── parts/
│   ├── part_kit.ex                 # PartKit schema
│   └── part_kit_compatibility.ex   # Engine compatibility join schema
├── user_bikes.ex                   # UserBikes context (garage, images, mods)
├── user_bikes/
│   ├── user_bike.ex                # UserBike schema (user's bike registration)
│   ├── user_bike_image.ex          # UserBikeImage schema (R2-stored photos)
│   └── user_bike_mod.ex            # UserBikeMod schema (rider modifications)
├── storage.ex                      # Cloudflare R2 object storage
├── storage/s3_signer.ex            # AWS Signature V4 for R2
├── currency.ex                     # Currency helpers
├── kovy_assistant.ex               # GenServer — dispatches chat to TaskSupervisor → Groq
├── kovy_assistant/
│   ├── prompt.ex                   # Builds structured system prompts from bike data + rider mods + rider orders
│   ├── context_builder.ex          # Builds context maps for prompts
│   ├── embeddings.ex               # OpenAI text-embedding-3-small integration
│   ├── groq.ex                     # Groq API client — streaming SSE + sync modes
│   ├── groq_behaviour.ex           # Behaviour for Mox testing
│   ├── groq_error.ex               # Groq error struct
│   ├── input_sanitizer.ex          # Chat input sanitization (prompt injection prevention)
│   └── rate_limiter.ex             # Groq API rate limiter (GenServer)
├── mailer.ex                       # Swoosh mailer
├── postgrex_types.ex               # Custom Postgrex types (pgvector)
├── release.ex                      # Release tasks (migrations)
└── repo.ex                         # Ecto Repo

lib/kove_web/
├── router.ex                       # Routes: /, /bikes/:slug, /home, /users/*
├── user_auth.ex                    # Auth plugs and on_mount hooks
├── live/
│   ├── storefront_live.ex          # Bike catalog grid + catalog-chat orchestration
│   ├── bike_details_live.ex        # Spec tabs (Marketing/Engine/Chassis) + single-bike chat
│   ├── user_home_live.ex           # My Garage: carousel, mods, photos, chat (~957 lines)
│   ├── chat_live.ex                # Shared Kovy chat UI component (desktop + mobile)
│   ├── chat_handlers.ex            # Shared chat handler macros/imports
│   ├── bike_helpers.ex             # Shared bike helper functions
│   └── user_live/
│       ├── registration.ex         # User registration
│       ├── login.ex                # Email/password login
│       ├── confirmation.ex         # Magic-link confirmation
│       └── settings.ex             # User settings (email, password)
├── components/
│   ├── core_components.ex
│   ├── layouts.ex
│   └── layouts/root.html.heex
└── controllers/
  ├── google_auth_controller.ex   # Google OAuth start/callback handlers
    ├── error_html.ex
    ├── error_json.ex
    ├── page_controller.ex
    └── user_session_controller.ex

test/
├── kove/
│   ├── accounts_test.exs
│   ├── kovy_assistant_test.exs
│   ├── bikes/, engines/, chassis_specs/, dimensions/, bike_features/
│   ├── images/, descriptions/, orders/, parts/
│   ├── user_bikes/mods_test.exs, user_bike_mod_test.exs
│   └── kovy_assistant/
│       ├── prompt_test.exs, groq_test.exs
│       ├── embeddings_test.exs, input_sanitizer_test.exs
├── kove_web/
│   ├── user_auth_test.exs
│   ├── controllers/
│   └── live/
│       ├── storefront_live_test.exs, storefront_live_chat_test.exs
│       ├── bike_details_live_chat_test.exs, bike_details_live_mobile_chat_test.exs
│       ├── bike_details_live_slider_test.exs
│       └── user_live/ (registration, login, confirmation, settings tests)
└── support/
    ├── conn_case.ex, data_case.ex, chat_case.ex
    └── fixtures/ (accounts_fixtures.ex, bikes_fixtures.ex)

priv/repo/migrations/               # 20+ migrations
├── enable_pgvector
├── create_engines, create_bikes, create_chassis_specs
├── create_dimensions, create_bike_features, create_images
├── create_descriptions, create_orders, create_parts_catalog
├── create_part_kit_compatibilities, evolve_orders_for_checkout, create_order_items
├── seed_oil_change_kits (idempotent data migration)
├── fix_mx450_engine_id, resize_description_embedding
├── create_users_auth_tables
├── create_user_bikes, create_user_bike_images
└── create_user_bike_mods

config/
├── config.exs, dev.exs, test.exs, prod.exs
└── runtime.exs                     # Loads all env vars / ../.env fallback

assets/js/app.js                    # Hooks: ScrollBottom (chat), Carousel (image slideshow)
```

## Kovy Assistant Architecture

```
ChatLive (LiveComponent)
  │ handle_event("send_message" | "toggle_chat")
  │ send(self(), {:chat_send, msg}) / send(self(), :chat_toggle)
  ▼
Parent LiveView
  │ BikeDetailsLive:  KovyAssistant.send_message(bike, history)
  │ StorefrontLive:   KovyAssistant.send_catalog_message(bikes_full, history)
  │ UserHomeLive:     KovyAssistant.send_message(bike, history, self(), context)
  │                   context includes rider_mods + user_orders for personalized answers
  ▼
KovyAssistant (GenServer)
  │ GenServer.cast → Task.Supervisor.start_child
  ▼
Task (async)
  ├── Prompt.build_system_prompt(bike)            # single-bike chat
  ├── Prompt.build_system_prompt(bike, rider_mods, user_orders)
  │                                            # My Garage chat (+ rider mods + order status)
  ├── Prompt.build_catalog_system_prompt/2         # storefront chat
  │    └── Prompt.relevant_bikes/2 (keyword pseudo-RAG)
  └── Groq.stream_chat(messages, caller_pid)
        │
        ▼  SSE chunks from Groq API
        send(caller_pid, {:kovy_chunk, text})
        send(caller_pid, {:kovy_done})
        │
        ▼
Parent LiveView.handle_info
  └── Updates chat assigns → ChatLive re-renders
```

The Groq module is swappable via `config :kove, :groq_module` — defaults to `Kove.KovyAssistant.Groq` in dev/prod, replaced by `Kove.KovyAssistant.GroqMock` (Mox) in tests.

## Database Schema

See [ERD.md](ERD.md) for detailed entity-relationship documentation.

```
users (1) ──< user_tokens
  │
  └──< user_bikes (1) ──< user_bike_images (R2 storage)
          │ ──< user_bike_mods (has vector(768) embedding)
          └── belongs_to bikes

engines (1) ──< bikes (1) ──< chassis_specs
                    │ ──< dimensions
                    │ ──< bike_features
                    │ ──< images
                    │ ──< descriptions (has vector(768) embedding)
                    ├──< orders ──< order_items >── belongs_to part_kits
                    └──< part_kit_compatibilities >── belongs_to part_kits

part_kits (1) ──< part_kit_compatibilities
          └──< order_items
```

20+ Ecto schemas across accounts, bikes, user_bikes, orders, parts, and kovy_assistant contexts. Six bikes seeded: 800X Rally, 800X Pro, 800X Adventure, 450 Rally, MX 250F, MX 450F across 4 engine platforms.

## Testing

### Unit / Integration (ExUnit)

```bash
# Run all tests
mix test

# Run specific test areas
mix test test/kove/kovy_assistant/          # Chat/prompt tests
mix test test/kove/user_bikes/              # Garage/mods tests
mix test test/kove_web/live/                # LiveView tests

# Pre-commit checks (compile warnings, format, tests)
mix precommit
```

Current status: **379 tests passing**.

### E2E (Playwright)

End-to-end tests live in `e2e/` and run against a real Phoenix server pointed at a local mock API server (no real Groq/OpenAI/Google calls). Four spec files:

| File | Covers |
|------|--------|
| `e2e/storefront.spec.ts` | Page structure, bike grid, Kovy chat panel (desktop + mobile FAB) on `/` |
| `e2e/bike-details.spec.ts` | Page structure, image slider, spec tabs, navigation, Kovy chat (desktop + mobile FAB) on `/bikes/:slug` |
| `e2e/auth.spec.ts` | Login/register page structure + Google OAuth login/registration flow |
| `e2e/privacy.spec.ts` | Footer privacy link + privacy page structure with all five main policy sections |

The mock API server (`e2e/support/mock-api-server.cjs`) stubs:
- `POST /openai/v1/chat/completions` — streams a canned SSE response word-by-word with a 3 s initial delay so the disabled-input state is observable
- `POST /v1/embeddings` — returns a fake 768-dim vector
- `GET /google/o/oauth2/v2/auth` — immediate redirect back to app callback with mock auth code + state
- `POST /google/oauth2/token` — returns a fake Google access token response
- `GET /google/oauth2/v3/userinfo` — returns a fake Google profile payload
- `GET /health` — Playwright readiness probe

```bash
# Run all E2E tests (starts mock server + Phoenix automatically)
npx playwright test

# Run a single spec file
npx playwright test e2e/storefront.spec.ts
npx playwright test e2e/bike-details.spec.ts

# Run headed (browser visible) for debugging
npx playwright test --headed

# Run a single test by name
npx playwright test -g 'bike grid'

# View HTML report from the last run
npx playwright show-report
```

**Running manually** (skip auto-start):
```bash
node e2e/support/mock-api-server.cjs &
GROQ_BASE_URL=http://localhost:4444 OPENAI_BASE_URL=http://localhost:4444 \
  GOOGLE_OAUTH_BASE_URL=http://localhost:4444/google \
  GROQ_API_KEY=mock OPENAI_API_KEY=mock \
  GOOGLE_OAUTH_CLIENT_ID=mock GOOGLE_OAUTH_CLIENT_SECRET=mock \
  GOOGLE_OAUTH_REDIRECT_URI=http://localhost:4000/auth/google/callback \
  mix phx.server &
npx playwright test
```

> **Note:** Both the Phoenix app and the mock API server set `reuseExistingServer` to `!process.env.CI`, so `reuseExistingServer` is `true` locally (when `CI` is not set) and `false` on CI. Locally, an already-running server can be reused; on CI, a fresh server is always started.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GROQ_API_KEY` | Yes (for chat) | Groq API key |
| `OPENAI_API_KEY` | Yes (for embeddings) | OpenAI API key |
| `DATABASE_URL` | Prod only | Neon PostgreSQL connection string |
| `SECRET_KEY_BASE` | Prod only | Phoenix secret |
| `R2_ACCOUNT_ID` | Yes (for photos) | Cloudflare R2 account ID |
| `R2_ACCESS_KEY_ID` | Yes (for photos) | R2 access key |
| `R2_SECRET_ACCESS_KEY` | Yes (for photos) | R2 secret key |
| `R2_BUCKET` | Yes (for photos) | R2 bucket name |
| `R2_PUBLIC_URL` | Yes (for photos) | R2 public URL prefix |
| `GOOGLE_OAUTH_CLIENT_ID` | Yes (for Google login) | Google OAuth client ID |
| `GOOGLE_OAUTH_CLIENT_SECRET` | Yes (for Google login) | Google OAuth client secret |
| `GOOGLE_OAUTH_REDIRECT_URI` | Yes (for Google login) | OAuth callback URL (`/auth/google/callback`) |
| `GOOGLE_OAUTH_BASE_URL` | E2E only | Local mock Google OAuth base URL (not used in production) |

Dev/test: auto-loaded from `../.env` file by `runtime.exs`. Prod: Fly.io secrets (`fly secrets set`).

## Deployment

Deployed on **Fly.io** via `fly deploy`. Uses `Dockerfile` with multi-stage build for Elixir releases. Database is **Neon PostgreSQL** with pgvector extension.

## What's Next

See [V2_PLAN.md](V2_PLAN.md) for the full roadmap including:
- Chat persistence (sessions + messages)
- LLM tool calling via Groq function calling
- Semantic search via pgvector embeddings
- Order lifecycle management
