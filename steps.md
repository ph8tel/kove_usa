# Kove USA MVP v1 — App Scaffold & Database Schema Plan

## Overview

Scaffold a Phoenix LiveView app with Postgres + pgvector to serve as the Kove USA motorcycle catalog, AI assistant (Kovy), and order-capture system. The schema normalizes the raw data in `bijes.json`, uses a **shared `engines` table** (4 engine platforms across 6 bikes, designed to grow in v3), stores all marketing paragraphs as `descriptions` rows with pgvector embeddings generated at seed time via the Groq API (`GROQ_API_KEY` from `.env`), and keeps compound values (e.g. "37.8″ High Seat / 36″ Low Seat") as plain strings.

---

## Step 1 — Scaffold the Phoenix project

- Run `mix phx.new kove --live --database postgres`
- Add deps to `mix.exs`:
  - `pgvector` (Ecto type for vector columns)
  - `req` (HTTP client for Groq embedding API)
  - `jason` (JSON — included by default)
- Configure Tailwind (ships with Phoenix 1.7+)
- Add `.env` support — read `GROQ_API_KEY` from env at runtime via `config/runtime.exs`
- Create a first migration that enables the pgvector extension:
  ```sql
  CREATE EXTENSION IF NOT EXISTS vector;
  ```

---

## Step 2 — Create `engines` table (shared platforms)

This table holds the **4 unique engine platforms** in the current lineup. Multiple bikes reference the same engine row. Designed to grow as the catalog expands in v3.

| Column              | Type     | Notes                                              |
|---------------------|----------|----------------------------------------------------|
| `id`                | `bigint` | PK                                                 |
| `platform_name`     | `string` | Human label, e.g. "799cc DOHC Parallel Twin"       |
| `engine_type`       | `string` | "Twin Cylinder, DOHC", "Single Cylinder, SOHC" …  |
| `displacement`      | `string` | "799cc", "449cc", "249cc" …                        |
| `bore_x_stroke`     | `string` | "88mm × 65.7mm" …                                  |
| `cooling`           | `string` | "Liquid-Cooled", "Liquid-Cooled with External Oil Cooler & Dual Fans" |
| `compression_ratio` | `string` | Nullable — known for some platforms                |
| `fuel_system`       | `string` | "Bosch EFI" across all current models              |
| `transmission`      | `string` | "5-Speed" or "6-Speed"                             |
| `clutch`            | `string` | "Oil Bath, Multi-Disc, Cable-Actuated" / "…Hydraulic-Actuated" |
| `starter`           | `string` | "Electric" for all current models                  |
| `max_power`         | `string` | Nullable — "95 HP", "52 HP @ 9500rpm" …           |
| `max_torque`        | `string` | Nullable — "32 ft-lbs @ 7500rpm" …                |
| `inserted_at`       | `utc_datetime` |                                               |
| `updated_at`        | `utc_datetime` |                                               |

**Seed data — 4 rows:**

| Platform Name              | Shared By                                      |
|----------------------------|------------------------------------------------|
| 799cc DOHC Parallel Twin   | 800X Rally, 800X Pro                           |
| 449cc DOHC Single          | 450 Rally Pro Off-Road, 450 Rally Street Legal |
| 449.9cc SOHC Single        | MX450 (sole user)                              |
| 249cc DOHC Finger-Follower | MX250 (sole user)                              |

---

## Step 3 — Create `bikes` table

| Column              | Type                       | Notes                                              |
|---------------------|----------------------------|----------------------------------------------------|
| `id`                | `bigint`                   | PK                                                 |
| `engine_id`         | `references(:engines)`     | FK → shared engine platform                        |
| `name`              | `string`                   | Full product name, e.g. "2026 Kove 800X Rally"     |
| `year`              | `integer`                  | 2026                                               |
| `variant`           | `string`                   | "Rally", "Pro", "Street Legal", "Pro Off-Road" …   |
| `slug`              | `string`                   | URL-safe unique key, e.g. "2026-800x-rally"        |
| `status`            | `string`                   | Enum: `street_legal` / `competition`               |
| `category`          | `string`                   | Enum: `adv` / `rally` / `mx`                       |
| `msrp_cents`        | `integer`                  | Price in cents (e.g. 1299900 for $12,999)          |
| `hero_image_url`    | `string`                   | URL of primary image                               |
| `exhaust_override`  | `string`                   | Nullable — "Full Titanium Closed-Course System"    |
| `sprocket_override` | `string`                   | Nullable — "51-tooth Rear"                         |
| `ecu_override`      | `string`                   | Nullable — "Race-tuned ECU"                        |
| `inserted_at`       | `utc_datetime`             |                                                    |
| `updated_at`        | `utc_datetime`             |                                                    |

**Indexes:** unique on `slug`, index on `engine_id`, `category`, `status`.

**Associations:** `belongs_to :engine` — many bikes can reference the same engine row.

---

## Step 4 — Create `chassis_specs` table (1:1 → bikes)

| Column              | Type                       | Notes                                              |
|---------------------|----------------------------|----------------------------------------------------|
| `id`                | `bigint`                   | PK                                                 |
| `bike_id`           | `references(:bikes)`       | FK, unique index                                   |
| `frame_type`        | `string`                   | Nullable — "Steel Perimeter", "Steel Semi-Perimeter" |
| `front_suspension`  | `string`                   | "49mm YU-AN Upside Fork, Fully Adjustable" …       |
| `front_travel`      | `string`                   | Nullable — "9.5″", "12″" …                        |
| `rear_suspension`   | `string`                   | "YU-AN Reservoir Monoshock, Fully Adjustable" …    |
| `rear_travel`       | `string`                   | Nullable                                           |
| `front_brake`       | `string`                   | "Single 310mm disc", "310mm Dual Disc, 4-Piston …"|
| `rear_brake`        | `string`                   | Nullable                                           |
| `abs_system`        | `string`                   | Nullable — normalize `abs`/`abs_system` into one   |
| `wheels`            | `string`                   |                                                    |
| `tires`             | `string`                   | Nullable                                           |
| `steering_angle`    | `string`                   | Nullable                                           |
| `rake_angle`        | `string`                   | Nullable                                           |
| `triple_clamp`      | `string`                   | Nullable — "Billet" (800X Rally only)              |
| `inserted_at`       | `utc_datetime`             |                                                    |
| `updated_at`        | `utc_datetime`             |                                                    |

---

## Step 5 — Create `dimensions` table (1:1 → bikes)

| Column              | Type                       | Notes                                              |
|---------------------|----------------------------|----------------------------------------------------|
| `id`                | `bigint`                   | PK                                                 |
| `bike_id`           | `references(:bikes)`       | FK, unique index                                   |
| `weight`            | `string`                   | "364 lbs", "408 lbs" — plain string                |
| `weight_type`       | `string`                   | Enum: `dry` / `curb`                               |
| `fuel_capacity`     | `string`                   | "5 Gallons", "8 Gallons (3 separate tanks)" …      |
| `estimated_range`   | `string`                   | Nullable — "Up to 250 miles", "300+ Miles"         |
| `overall_size`      | `string`                   | Nullable — "88.1″ x 34.7″ x 55.1″" …             |
| `wheelbase`         | `string`                   | Nullable                                           |
| `seat_height`       | `string`                   | Nullable — plain string for compound values        |
| `ground_clearance`  | `string`                   | Nullable — plain string for compound values        |
| `inserted_at`       | `utc_datetime`             |                                                    |
| `updated_at`        | `utc_datetime`             |                                                    |

---

## Step 6 — Create `bike_features` table (many → bikes)

Stores the `features` / `other_features` arrays from chassis specs as individual rows.

| Column     | Type                       | Notes                                         |
|------------|----------------------------|-----------------------------------------------|
| `id`       | `bigint`                   | PK                                            |
| `bike_id`  | `references(:bikes)`       | FK                                            |
| `name`     | `string`                   | "Integrated Crash Bars", "Skid Plate" …       |
| `position` | `integer`                  | Ordering within the bike's feature list       |

**Index:** unique composite on `bike_id` + `name`.

---

## Step 7 — Create `images` table (many → bikes)

| Column     | Type                       | Notes                                         |
|------------|----------------------------|-----------------------------------------------|
| `id`       | `bigint`                   | PK                                            |
| `bike_id`  | `references(:bikes)`       | FK                                            |
| `alt`      | `string`                   | Alt text from source data                     |
| `url`      | `string`                   | Absolute URL                                  |
| `position` | `integer`                  | Display order (first image = position 0)      |
| `is_hero`  | `boolean`                  | Default `false` — first image per bike = hero |

---

## Step 8 — Create `descriptions` table with pgvector (many → bikes)

Each paragraph from `marketing_text` becomes one row. Embeddings generated at seed time via Groq.

| Column      | Type                       | Notes                                       |
|-------------|----------------------------|---------------------------------------------|
| `id`        | `bigint`                   | PK                                          |
| `bike_id`   | `references(:bikes)`       | FK                                          |
| `kind`      | `string`                   | "marketing" now; "maintenance", "user_note" later |
| `body`      | `text`                     | One paragraph of marketing text             |
| `position`  | `integer`                  | Paragraph ordering within its kind          |
| `embedding` | `vector(1536)`             | pgvector — populated at seed time           |

**Indexes:**
- HNSW index on `embedding` for cosine-similarity search
- Composite index on `bike_id` + `kind` + `position`

---

## Step 9 — Create `orders` table

| Column          | Type                       | Notes                               |
|-----------------|----------------------------|--------------------------------------|
| `id`            | `bigint`                   | PK                                   |
| `bike_id`       | `references(:bikes)`       | FK                                   |
| `customer_name` | `string`                   |                                      |
| `customer_email`| `string`                   |                                      |
| `customer_phone`| `string`                   |                                      |
| `notes`         | `text`                     | Nullable                             |
| `inserted_at`   | `utc_datetime`             |                                      |
| `updated_at`    | `utc_datetime`             |                                      |

---

## Step 10 — Seed script with embedding generation

**File:** `priv/repo/seeds.exs`

**Sequence:**
1. Read and parse `bijes.json`
2. Build a map of unique engines by `{displacement, bore_x_stroke, engine_type}` → insert into `engines` table (4 rows), keep an id lookup map
3. For each bike object:
   - Derive `year`, `variant`, `slug`, `status`, `category`, `msrp_cents` from raw fields
   - Look up `engine_id` from the engines map
   - Extract `exhaust_override`, `sprocket_override`, `ecu_override` (450 Rally Pro only)
   - Insert `bikes` row
   - Insert `chassis_specs` row — normalize `abs`/`abs_system` → `abs_system`; merge `suspension_travel` into `front_travel`/`rear_travel`
   - Insert `dimensions` row — detect `dry_weight` vs `curb_weight` → set `weight` + `weight_type`
   - Insert `bike_features` rows from `features` or `other_features` array
   - Insert `images` rows — first image gets `is_hero: true`
   - For each paragraph in `marketing_text`:
     - Insert `descriptions` row with `kind: "marketing"`, `body`, `position`
     - Call Groq embeddings API to generate a 1536-dim vector
     - Store the vector in the `embedding` column

**Groq embedding call:**
- Endpoint: `POST https://api.groq.com/openai/v1/embeddings`
- Auth: `Authorization: Bearer ${GROQ_API_KEY}` (from `.env`)
- Rate-limit: ~100ms delay between calls to avoid throttling; ~40 total paragraphs across 6 bikes

**Field normalization rules during seeding:**

| Source inconsistency | Normalization |
|----------------------|---------------|
| `horsepower: "95 HP"` vs `max_power: "52 HP @ 9500rpm"` | → `engines.max_power` |
| `dry_weight` vs `curb_weight` | → `dimensions.weight` + `dimensions.weight_type` |
| `features` vs `other_features` | → `bike_features` rows |
| `abs` vs `abs_system` | → `chassis_specs.abs_system` |
| `suspension_travel` vs `front_travel`/`rear_travel` | → If only `suspension_travel`, copy to both; if split, use directly |
| `exhaust`, `sprocket` in engine specs | → `bikes.exhaust_override`, `bikes.sprocket_override` |

---

## Entity-Relationship Diagram

```
┌──────────┐       ┌──────────────┐
│ engines  │──1:N──│    bikes     │
└──────────┘       └──────┬───────┘
                          │
          ┌───────────────┼───────────────┬──────────────┬───────────────┐
          │ 1:1           │ 1:1           │ 1:N          │ 1:N           │
   ┌──────┴───────┐ ┌─────┴──────┐ ┌─────┴──────┐ ┌─────┴──────┐ ┌─────┴──────┐
   │ chassis_specs│ │ dimensions │ │bike_features│ │   images   │ │descriptions│
   └──────────────┘ └────────────┘ └────────────┘ └────────────┘ └────────────┘
                                                                        │
                          ┌────────────┐                          (pgvector
                          │   orders   │──N:1── bikes              embedding)
                          └────────────┘
```

---

## Migration Run Order

1. `enable_pgvector` — `CREATE EXTENSION IF NOT EXISTS vector`
2. `create_engines`
3. `create_bikes` — depends on `engines`
4. `create_chassis_specs` — depends on `bikes`
5. `create_dimensions` — depends on `bikes`
6. `create_bike_features` — depends on `bikes`
7. `create_images` — depends on `bikes`
8. `create_descriptions` — depends on `bikes`, uses `vector(1536)`
9. `create_orders` — depends on `bikes`

Then run `mix ecto.setup` which runs migrations + seeds (including Groq embedding calls).
