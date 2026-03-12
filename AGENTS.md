This is **Kove Moto USA** — a Phoenix 1.8 / LiveView 1.1 motorcycle catalog and rider garage app with an AI chat assistant ("Kovy") powered by Groq. Deployed on Fly.io at `kove.fly.dev`.

## Application Overview

Kove Moto USA is a product catalog and personalized rider dashboard for Kove motorcycles sold in the US market. It has:

- A **storefront** (`/`) showing a 2×3 grid of bike cards plus a catalog-wide streaming Kovy chat panel
- **Bike detail pages** (`/bikes/:slug`) with spec tabs (Marketing, Engine, Chassis) and the same streaming Kovy chat UI in single-bike context
- **User authentication** via `phx.gen.auth` with magic-link login and email/password
- **My Garage** (`/home`) — an authenticated rider dashboard with:
  - Image carousel for user-uploaded bike photos (Cloudflare R2 storage)
  - **My Mods** tab — track rider modifications (exhaust, suspension, gearing, etc.) with dollar cost input and 5-star rating
  - **Photos** tab — upload/manage bike photos via form-based R2 uploads
  - **Kovy chat** contextualized with the user's specific bike and rider mods
- **Kovy**, an AI assistant backed by Groq's `llama-3.3-70b-versatile` model that answers questions grounded in real bike spec data and (when on `/home`) the rider's own modifications

## Key Architecture Decisions

- **Auth via `phx.gen.auth`** — magic-link login, email/password, session tokens. Public routes (`/`, `/bikes/:slug`) work with or without auth. `/home` requires authentication.
- **Groq module is swappable** via `config :kove, :groq_module` (defaults to `Kove.KovyAssistant.Groq`, replaced by `GroqMock` in tests via Mox)
- **Chat is streaming** — Groq SSE chunks flow: Task → `send(caller_pid, {:kovy_chunk, text})` → LiveView `handle_info` → assign update → re-render
- **Shared `ChatLive` LiveComponent** renders both desktop panel and mobile FAB/drawer; parent LiveViews own state via `handle_info`
- **Storefront chat uses pseudo-RAG** — keyword matching (`Prompt.relevant_bikes/2`) selects which bikes get full detail context per message
- **User home chat includes rider mods** — `Prompt.build_system_prompt/2` accepts an optional `rider_mods` list to inject the rider's modifications into the LLM context
- **pgvector** extension is enabled; `descriptions.embedding` (vector 768) and `user_bike_mods.embedding` (vector 768) columns exist for future semantic search
- **Cloudflare R2** for user photo storage — upload/delete via `Kove.Storage` with AWS Sig V4 signing (`Kove.Storage.S3Signer`)
- **Groq rate limiting** via `Kove.KovyAssistant.RateLimiter` GenServer
- **Input sanitization** via `Kove.KovyAssistant.InputSanitizer` to prevent prompt injection
- **daisyUI 5** on Tailwind CSS 4.1 — use daisyUI component classes (`btn`, `card`, `tabs`, `input`, etc.)
- **Dollar/cents conversion in UI** — DB stores `cost_cents` as integer, LiveView converts to/from dollars for display

## Database Schema

```
users (1) ──< user_tokens
  │
  └──< user_bikes (1) ──< user_bike_images
          │ ──< user_bike_mods (has vector(768) embedding column)
          └── belongs_to bikes

engines (1) ──< bikes (1) ──< chassis_specs
                    │ ──< dimensions
                    │ ──< bike_features
                    │ ──< images
                    │ ──< descriptions (has vector(768) embedding column)
                    └──< orders
```

**Contexts:**
- `Kove.Bikes` — `list_bikes/0`, `list_bikes_full/0`, `get_bike_by_slug/1`, `get_bike!/1`, `hero_image_url/1`, `format_msrp/1`
- `Kove.Accounts` — user registration, authentication, magic-link login, session management
- `Kove.UserBikes` — `get_user_bike/1`, `create_user_bike/2`, image CRUD (`add_image/3`, `delete_image/1`), mod CRUD (`add_mod/2`, `update_mod/2`, `delete_mod/1`, `list_mods/1`)
- `Kove.Storage` — Cloudflare R2 upload/delete/public_url

## Supervision Tree

```
Kove.Supervisor (one_for_one)
├── KoveWeb.Telemetry
├── Kove.Repo
├── DNSCluster
├── Phoenix.PubSub
├── Task.Supervisor (Kove.TaskSupervisor)       ← spawns Groq streaming tasks
├── Kove.KovyAssistant.RateLimiter (GenServer)  ← rate limiter for Groq API
├── Kove.KovyAssistant (GenServer)              ← receives chat casts, dispatches to TaskSupervisor
└── KoveWeb.Endpoint
```

## KovyAssistant Chat Flow

1. `ChatLive` receives `"send_message"` / `"toggle_chat"` and relays to parent via `send(self(), {:chat_send, msg})` / `send(self(), :chat_toggle)`
2. Parent LiveView handles `{:chat_send, msg}`:
  - `BikeDetailsLive` → `KovyAssistant.send_message(bike, history, self())`
  - `StorefrontLive` → `KovyAssistant.send_catalog_message(bikes_full, history, self())`
  - `UserHomeLive` → `KovyAssistant.send_message(bike, history, self(), context)` (includes `rider_mods`)
3. `KovyAssistant` (GenServer) casts → `Task.Supervisor.start_child` with an async function
4. Task builds prompt:
  - single-bike: `Prompt.build_system_prompt/1`
  - single-bike + mods: `Prompt.build_system_prompt/2` (with `rider_mods` list)
  - catalog: `Prompt.build_catalog_system_prompt/2` (summary of all bikes + detailed specs only for keyword-matched bikes)
5. Task calls `groq_module().stream_chat(messages, caller_pid)` — streams SSE from Groq API
6. Each SSE chunk sends `{:kovy_chunk, text}` to the LiveView pid; `:kovy_done` / `:kovy_error` at end
7. Parent LiveView `handle_info` updates `chat_messages`/`chat_loading`/`chat_open` assigns → component re-renders

## Testing

### ExUnit (unit + integration)
- **379 tests** across app/context/schema/liveview/auth layers, all passing
- **Mox** is used for the Groq client — `GroqBehaviour` defines the contract, `GroqMock` replaces it in test env
- Tests that exercise the GenServer → Task pipeline use `set_mox_global` (not async) because Mox expectations must cross process boundaries
- Schema tests validate changesets and constraints for all schemas (Bike, Engine, ChassisSpec, Dimension, BikeFeature, Image, Description, Order, UserBike, UserBikeMod, UserBikeImage)
- LiveView tests use `Phoenix.LiveViewTest` — send events, simulate streaming callbacks via `send(view.pid, {:kovy_chunk, ...})`
- Auth tests cover registration, login, magic-link confirmation, settings, session management
- Run: `mix test` or `mix precommit` (compile warnings + format + tests)

### Playwright (E2E)
- **Two spec files** in `e2e/`: `storefront.spec.ts` and `bike-details.spec.ts`
- A local **mock API server** (`e2e/support/mock-api-server.cjs`) intercepts all Groq and OpenAI calls — no real API keys needed
- The mock streams a canned response with a **3 s initial delay** so the `chat_loading = true` disabled-input state is observable by Playwright's polling
- `GROQ_BASE_URL` / `OPENAI_BASE_URL` are injected by `playwright.config.ts` via `webServer.env`; they are **not set on Fly.io** — production always hits the real APIs
- The mock API server uses `reuseExistingServer: false` locally so code changes are always picked up; Phoenix uses `reuseExistingServer: true` so a running dev server is reused
- Image-slider tests guard against single-image bikes by checking for the "Next image" button (2 s timeout) before running, rather than calling `textContent()` which would hang until the action timeout
- Run: `npx playwright test` or target a single file: `npx playwright test e2e/storefront.spec.ts`

## File Layout

```
lib/kove/
├── accounts.ex                 # Accounts context (auth, users, tokens)
├── accounts/
│   ├── scope.ex                # Kove.Accounts.Scope
│   ├── user.ex                 # User schema
│   ├── user_notifier.ex        # Email notifications (magic link, etc.)
│   └── user_token.ex           # Session/magic-link tokens
├── bikes.ex                    # Bikes context: queries, formatting helpers
├── bikes/bike.ex               # Bike schema (belongs_to :engine, has_one/has_many assocs)
├── engines/engine.ex           # Engine schema
├── chassis_specs/chassis_spec.ex
├── dimensions/dimension.ex
├── bike_features/bike_feature.ex
├── images/image.ex
├── descriptions/description.ex # Has :embedding field (pgvector, 768 dims)
├── orders/order.ex
├── user_bikes.ex               # UserBikes context (garage, images, mods)
├── user_bikes/
│   ├── user_bike.ex            # UserBike schema (user's bike registration)
│   ├── user_bike_image.ex      # UserBikeImage schema (R2-stored photos)
│   └── user_bike_mod.ex        # UserBikeMod schema (rider modifications)
├── storage.ex                  # Cloudflare R2 object storage
├── storage/
│   └── s3_signer.ex            # AWS Signature V4 for R2
├── currency.ex                 # Currency helpers
├── kovy_assistant.ex           # GenServer — chat dispatch
├── kovy_assistant/
│   ├── prompt.ex               # Builds structured system prompt from bike data + rider mods
│   ├── context_builder.ex      # Builds context maps for prompts
│   ├── embeddings.ex           # OpenAI text-embedding-3-small integration
│   ├── groq.ex                 # Groq HTTP client (streaming SSE + sync)
│   ├── groq_behaviour.ex       # @callback definitions for Mox
│   ├── groq_error.ex           # Groq error struct
│   ├── input_sanitizer.ex      # Chat input sanitization
│   └── rate_limiter.ex         # Groq API rate limiter (GenServer)
├── mailer.ex                   # Swoosh mailer
├── postgrex_types.ex           # Custom Postgrex types (pgvector)
├── release.ex                  # Release tasks (migrations)
└── repo.ex                     # Ecto Repo

lib/kove_web/
├── router.ex                   # Routes: /, /bikes/:slug, /home, /users/*
├── user_auth.ex                # Auth plugs and on_mount hooks
├── live/
│   ├── storefront_live.ex      # Bike catalog grid + catalog-chat orchestration
│   ├── bike_details_live.ex    # Spec tabs (Marketing/Engine/Chassis) + single-bike chat
│   ├── user_home_live.ex       # My Garage: carousel, mods, photos, chat (~957 lines)
│   ├── chat_live.ex            # Shared Kovy chat UI component (desktop + mobile)
│   ├── chat_handlers.ex        # Shared chat handler macros/imports
│   ├── bike_helpers.ex         # Shared bike helper functions
│   └── user_live/
│       ├── registration.ex     # User registration
│       ├── login.ex            # Email/password login
│       ├── confirmation.ex     # Magic-link confirmation
│       └── settings.ex         # User settings (email, password)
├── components/
│   ├── core_components.ex
│   ├── layouts.ex
│   └── layouts/root.html.heex
└── controllers/
    ├── error_html.ex
    ├── error_json.ex
    ├── page_controller.ex
    └── user_session_controller.ex

e2e/
├── storefront.spec.ts          # Playwright: storefront page structure, bike grid, Kovy chat
├── bike-details.spec.ts        # Playwright: detail page structure, spec tabs, image slider, Kovy chat
└── support/
    └── mock-api-server.cjs     # Node.js stub for Groq + OpenAI APIs (SSE + embeddings)

config/
├── config.exs                  # Base config
├── dev.exs                     # Dev DB config
├── test.exs                    # Test DB + Mox groq_module config
├── prod.exs                    # Prod config
└── runtime.exs                 # Loads all env vars / ../.env fallback

assets/js/app.js                # Hooks: ScrollBottom (chat), Carousel (image slideshow)
```

## Environment

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

- Dev/test: auto-loaded from `../.env` file by `runtime.exs`
- Prod: Fly.io secrets (`fly secrets set`)
- Dev DB: `kove_dev` on localhost:5432 (postgres/postgres)
- Test DB: `kove_test` with Ecto sandbox
- Prod DB: Neon PostgreSQL with pgvector

## Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps
- When adding new Groq-dependent logic, always go through the `GroqBehaviour` so it stays testable with Mox
- When modifying prompt construction, run the prompt tests: `mix test test/kove/kovy_assistant/prompt_test.exs`
- Reuse `KoveWeb.ChatLive` for chat UI changes; keep streaming/state orchestration in parent LiveView `handle_info` callbacks
### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content
- The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will will save steps and prevent errors
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
custom classes must fully style the input

<!-- phoenix-gen-auth-start -->
## Authentication

- **Always** handle authentication flow at the router level with proper redirects
- **Always** be mindful of where to place routes. `phx.gen.auth` creates multiple router plugs and `live_session` scopes:
  - A plug `:fetch_current_scope_for_user` that is included in the default browser pipeline
  - A plug `:require_authenticated_user` that redirects to the log in page when the user is not authenticated
  - A `live_session :current_user` scope - for routes that need the current user but don't require authentication, similar to `:fetch_current_scope_for_user`
  - A `live_session :require_authenticated_user` scope - for routes that require authentication, similar to the plug with the same name
  - In both cases, a `@current_scope` is assigned to the Plug connection and LiveView socket
  - A plug `redirect_if_user_is_authenticated` that redirects to a default path in case the user is authenticated - useful for a registration page that should only be shown to unauthenticated users
- **Always let the user know in which router scopes, `live_session`, and pipeline you are placing the route, AND SAY WHY**
- `phx.gen.auth` assigns the `current_scope` assign - it **does not assign a `current_user` assign**
- Always pass the assign `current_scope` to context modules as first argument. When performing queries, use `current_scope.user` to filter the query results
- To derive/access `current_user` in templates, **always use the `@current_scope.user`**, never use **`@current_user`** in templates or LiveViews
- **Never** duplicate `live_session` names. A `live_session :current_user` can only be defined __once__ in the router, so all routes for the `live_session :current_user`  must be grouped in a single block
- Anytime you hit `current_scope` errors or the logged in session isn't displaying the right content, **always double check the router and ensure you are using the correct plug and `live_session` as described below**

### Routes that require authentication

LiveViews that require login should **always be placed inside the __existing__ `live_session :require_authenticated_user` block**:

    scope "/", AppWeb do
      pipe_through [:browser, :require_authenticated_user]

      live_session :require_authenticated_user,
        on_mount: [{KoveWeb.UserAuth, :require_authenticated}] do
        # phx.gen.auth generated routes
        live "/users/settings", UserLive.Settings, :edit
        live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
        # our own routes that require logged in user
        live "/", MyLiveThatRequiresAuth, :index
      end
    end

Controller routes must be placed in a scope that sets the `:require_authenticated_user` plug:

    scope "/", AppWeb do
      pipe_through [:browser, :require_authenticated_user]

      get "/", MyControllerThatRequiresAuth, :index
    end

### Routes that work with or without authentication

LiveViews that can work with or without authentication, **always use the __existing__ `:current_user` scope**, ie:

    scope "/", MyAppWeb do
      pipe_through [:browser]

      live_session :current_user,
        on_mount: [{KoveWeb.UserAuth, :mount_current_scope}] do
        # our own routes that work with or without authentication
        live "/", PublicLive
      end
    end

Controllers automatically have the `current_scope` available if they use the `:browser` pipeline.

<!-- phoenix-gen-auth-end -->

<!-- usage-rules-start -->
<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
<!-- phoenix:elixir-end -->
<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it
<!-- phoenix:phoenix-end -->
<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
<!-- phoenix:ecto-end -->
<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`
- Remember anytime you use `phx-hook="MyHook"` and that js hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Never** write embedded `<script>` tags in HEEx. Instead always write your scripts and hooks in the `assets/js` directory and integrate them with the `assets/js/app.js` file

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
        socket
        |> assign(:messages_empty?, messages == [])
        # reset the stream with the new messages
        |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @stream.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
<!-- phoenix:liveview-end -->
<!-- usage-rules-end -->