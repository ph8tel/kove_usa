Project setup and core scaffolding
- Initialize Phoenix + LiveView project with Postgres and Ecto.
- Install pgvector extension in Postgres and add the Ecto type.
- Set up base modules: Bike, EngineSpec, ChassisSpec, Description.
- Create seeds file for manually entering the 2026 bike data.
- Add basic LiveView layout with clean, modern styling (Tailwind or your preferred system).

Database schema and migrations
- Create bikes table with fields for model name, year, variant, summary, hero image.
- Create engine_specs table with 1‑1 relation to bikes.
- Create chassis_specs table with 1‑1 relation to bikes.
- Create descriptions table with 1‑many relation to bikes and a kind field.
- Add embedding column to descriptions using pgvector.
- Add indexes for vector similarity search (IVFFlat or HNSW).
- Seed all 2026 models with engine, chassis, and long‑form descriptions.

Assistant foundation (public storefront)
- Create a GenServer “KovyAssistant” to handle:
- structured prompts
- Groq calls
- streaming responses
- Write the base prompt template for “sales clerk” mode:
- technical, non‑salesy tone
- comparisons to KTM/Husky
- maintenance expectations
- upgrade recommendations
- Add a LiveComponent chat UI for Kovy on the bike detail page.
- Implement structured Q&A:
- “How is this different from my Husky?”
- “What should I expect for maintenance?”
- “What upgrades do riders make?”
- Add semantic search over descriptions using pgvector for richer answers.

Public storefront UI
- Create bikes index page with clean cards and model/year filters.
- Create bike detail page showing:
- engine specs
- chassis specs
- dimensions
- long‑form descriptions
- Kovy assistant panel
- Add search bar for model names and keywords.
- Add comparison UI (optional but high impact):
- “Compare to KTM 450”
- “Compare to Husky FE450”
- Add “Ask Kovy” CTA on each bike page.

Order capture (no payments)
- Create orders table with:
- user info (name, email, phone)
- selected bike
- notes
- timestamp
- Add simple order form on bike detail page.
- Write order to DB and show confirmation.
- Add admin page (simple LiveView) for importer to view orders.

Step 2: User home + RAG (after MVP demo)
- Add auth (Pow or Phoenix Auth).
- Create user_bikes table for owned bikes.
- Add RAG pipeline:
- embed descriptions
- embed maintenance docs (once provided)
- embed user notes
- Add assistant “support mode”:
- torque specs
- maintenance intervals
- troubleshooting
- parts recommendations (once catalog is available)
- Add user dashboard with:
- their bike(s)
- maintenance reminders
- saved conversations
- recommended parts (future)

Demo preparation
- Script a sample conversation showing:
- KTM/Husky comparison
- maintenance expectations
- upgrade recommendations
- Dakar references
- Prepare a clean landing page explaining:
- “Meet Kovy — your rally bike assistant”
- “Technical answers, not sales pitches”
- “Built for riders, mechanics, and the Kove community”
- Record a short screen capture walking through:
- browsing bikes
- asking Kovy questions
- placing an order
