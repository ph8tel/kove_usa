# Kove Moto USA — Entity Relationship Diagram

> Database: PostgreSQL with pgvector extension
> Embedding dimension: 768 (OpenAI `text-embedding-3-small`)
> All tables use `utc_datetime` timestamps (`inserted_at`, `updated_at`)

---

## Visual ERD

```
┌─────────────────────┐
│       engines        │
├─────────────────────┤
│ id (PK)              │
│ platform_name        │
│ engine_type          │
│ displacement         │
│ bore_x_stroke        │
│ cooling              │
│ compression_ratio    │
│ fuel_system          │
│ transmission         │
│ clutch               │
│ starter              │
│ max_power            │
│ max_torque           │
│ timestamps           │
└────────┬────────────┘
         │ 1
         │
         │ *
┌────────┴────────────────────────────────────────────────────────────────┐
│                                bikes                                    │
├─────────────────────────────────────────────────────────────────────────┤
│ id (PK)                                                                 │
│ engine_id (FK → engines)                                                │
│ name, year, variant, slug (unique)                                      │
│ status (enum: street_legal | competition)                               │
│ category (enum: adv | rally | mx)                                       │
│ msrp_cents, hero_image_url                                              │
│ exhaust_override, sprocket_override, ecu_override                       │
│ timestamps                                                              │
└──┬──────────┬──────────┬──────────┬──────────┬──────────┬───────────────┘
   │ 1        │ 1        │ 1        │ 1        │ 1        │ 1
   │          │          │          │          │          │
   │ 0..1     │ 0..1     │ *        │ *        │ *        │ *
   │          │          │          │          │          │
   ▼          ▼          ▼          ▼          ▼          ▼
┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌────────────┐┌──────────┐
│ chassis  ││dimensions││  bike    ││  images  ││descriptions││  orders  │
│ _specs   ││          ││_features ││          ││            ││          │
├──────────┤├──────────┤├──────────┤├──────────┤├────────────┤├──────────┤
│id (PK)   ││id (PK)   ││id (PK)   ││id (PK)   ││id (PK)     ││id (PK)   │
│bike_id   ││bike_id   ││bike_id   ││bike_id   ││bike_id     ││bike_id   │
│(FK)      ││(FK)      ││(FK)      ││(FK)      ││(FK)        ││(FK)      │
│frame_type││weight    ││name      ││alt       ││kind (enum) ││cust_name │
│front_susp││weight_   ││position  ││url       ││body        ││cust_email│
│front_trvl││ type     ││timestamps││position  ││position    ││cust_phone│
│rear_susp ││ (enum)   ││          ││is_hero   ││embedding   ││notes     │
│rear_trvl ││fuel_cap  ││          ││timestamps││ ⚡vector   ││timestamps│
│front_brk ││est_range ││          ││          ││ (768)      ││          │
│rear_brk  ││overall_  ││          ││          ││timestamps  ││          │
│abs_system││ size     ││          ││          ││            ││          │
│wheels    ││wheelbase ││          ││          ││            ││          │
│tires     ││seat_hght ││          ││          ││            ││          │
│steer_angl││grnd_clr  ││          ││          ││            ││          │
│rake_angle││timestamps││          ││          ││            ││          │
│triple_clp││          ││          ││          ││            ││          │
│timestamps││          ││          ││          ││            ││          │
└──────────┘└──────────┘└──────────┘└──────────┘└────────────┘└──────────┘


┌──────────────────────┐
│        users         │
├──────────────────────┤
│ id (PK)              │
│ email (unique)       │
│ hashed_password      │
│ confirmed_at         │
│ timestamps           │
└──┬───────────┬───────┘
   │ 1         │ 1
   │           │
   │ *         │ *
   ▼           ▼
┌──────────┐ ┌──────────────────────────┐
│ users_   │ │       user_bikes         │
│ tokens   │ ├──────────────────────────┤
├──────────┤ │ id (PK)                  │
│id (PK)   │ │ user_id (FK → users)     │
│token     │ │ bike_id (FK → bikes)     │
│context   │ │ nickname                 │
│sent_to   │ │ bike_image_url           │
│auth_at   │ │ timestamps               │
│user_id   │ └──┬──────────┬────────────┘
│(FK)      │    │ 1        │ 1
│timestamps│    │          │
└──────────┘    │ *        │ *
                ▼          ▼
      ┌──────────────┐ ┌───────────────────┐
      │ user_bike_   │ │  user_bike_mods   │
      │ images       │ ├───────────────────┤
      ├──────────────┤ │ id (PK)           │
      │id (PK)       │ │ user_bike_id (FK) │
      │user_bike_id  │ │ mod_type (enum)   │
      │ (FK)         │ │ description       │
      │url           │ │ brand             │
      │storage_key   │ │ cost_cents        │
      │position      │ │ installed_at      │
      │timestamps    │ │ rating (1-5)      │
      └──────────────┘ │ position          │
                       │ embedding         │
                       │  ⚡vector (768)   │
                       │ timestamps        │
                       └───────────────────┘
```

---

## Table Details

### `engines`

The engine platform shared across multiple bike variants.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK, auto-increment | |
| `platform_name` | `string` | **required** | e.g. "800 Twin", "450 Single" |
| `engine_type` | `string` | **required** | e.g. "parallel-twin DOHC 8V" |
| `displacement` | `string` | **required** | e.g. "799cc" |
| `bore_x_stroke` | `string` | **required** | e.g. "88mm × 65.7mm" |
| `cooling` | `string` | **required** | e.g. "Liquid-cooled" |
| `compression_ratio` | `string` | optional | e.g. "12.5:1" |
| `fuel_system` | `string` | **required** | e.g. "Bosch EFI, dual 42mm TB" |
| `transmission` | `string` | **required** | e.g. "6-speed" |
| `clutch` | `string` | **required** | e.g. "Wet multi-plate, slipper" |
| `starter` | `string` | **required** | e.g. "Electric" |
| `max_power` | `string` | optional | e.g. "95 HP @ 9,000 rpm" |
| `max_torque` | `string` | optional | e.g. "78 Nm @ 6,500 rpm" |

**Relationships:** `has_many :bikes`

---

### `bikes`

The central product entity — a specific motorcycle model/variant.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `engine_id` | `bigint` | FK → engines, **required** | |
| `name` | `string` | **required** | e.g. "Kove 800X Rally" |
| `year` | `integer` | **required** | e.g. 2025 |
| `variant` | `string` | **required** | e.g. "Rally", "Pro", "Adventure" |
| `slug` | `string` | **required**, unique | URL-safe identifier |
| `status` | `enum` | **required** | `street_legal` \| `competition` |
| `category` | `enum` | **required** | `adv` \| `rally` \| `mx` |
| `msrp_cents` | `integer` | optional | Price in cents |
| `hero_image_url` | `string` | optional | Primary display image URL |
| `exhaust_override` | `string` | optional | Variant-specific exhaust spec |
| `sprocket_override` | `string` | optional | Variant-specific sprocket spec |
| `ecu_override` | `string` | optional | Variant-specific ECU mapping |

**Relationships:**
- `belongs_to :engine`
- `has_one :chassis_spec`
- `has_one :dimension`
- `has_many :bike_features`
- `has_many :images`
- `has_many :descriptions`

---

### `chassis_specs`

Suspension, brakes, and frame details for a bike. One-to-one with `bikes`.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `bike_id` | `bigint` | FK → bikes, **required** | |
| `frame_type` | `string` | optional | e.g. "Steel trellis, Cr-Mo" |
| `front_suspension` | `string` | optional | e.g. "KYB 48mm inverted fork" |
| `front_travel` | `string` | optional | e.g. "230mm" |
| `rear_suspension` | `string` | optional | e.g. "KYB fully adjustable" |
| `rear_travel` | `string` | optional | e.g. "220mm" |
| `front_brake` | `string` | optional | |
| `rear_brake` | `string` | optional | |
| `abs_system` | `string` | optional | e.g. "Bosch 9.3 2-ch ABS, off-road mode" |
| `wheels` | `string` | optional | |
| `tires` | `string` | optional | |
| `steering_angle` | `string` | optional | |
| `rake_angle` | `string` | optional | |
| `triple_clamp` | `string` | optional | |

---

### `dimensions`

Weight, size, and capacity specs. One-to-one with `bikes`.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `bike_id` | `bigint` | FK → bikes, **required** | |
| `weight` | `string` | optional | e.g. "209 kg" |
| `weight_type` | `enum` | optional | `dry` \| `curb` |
| `fuel_capacity` | `string` | optional | e.g. "20L" |
| `estimated_range` | `string` | optional | |
| `overall_size` | `string` | optional | |
| `wheelbase` | `string` | optional | |
| `seat_height` | `string` | optional | e.g. "870mm" |
| `ground_clearance` | `string` | optional | |

---

### `bike_features`

Ordered list of notable features per bike.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `bike_id` | `bigint` | FK → bikes, **required** | |
| `name` | `string` | **required** | Feature description text |
| `position` | `integer` | optional | Display order |

---

### `images`

Product photos for catalog display.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `bike_id` | `bigint` | FK → bikes, **required** | |
| `url` | `string` | **required** | Image URL |
| `alt` | `string` | optional | Alt text |
| `position` | `integer` | optional | Display order |
| `is_hero` | `boolean` | default: `false` | Hero image flag |

---

### `descriptions`

Marketing/maintenance text blocks with optional vector embeddings for semantic search.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `bike_id` | `bigint` | FK → bikes, **required** | |
| `kind` | `enum` | **required** | `marketing` \| `maintenance` |
| `body` | `text` | **required** | Description content |
| `position` | `integer` | optional | Display order |
| `embedding` | `vector(768)` | optional | ⚡ pgvector — OpenAI `text-embedding-3-small` |

**Note:** Queries exclude the `embedding` column by default via `descriptions_without_embedding` to reduce DB transfer overhead.

---

### `orders`

Basic order/inquiry capture (placeholder — no user association yet).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `bike_id` | `bigint` | FK → bikes, **required** | |
| `customer_name` | `string` | **required** | |
| `customer_email` | `string` | **required** | Validated `@` format |
| `customer_phone` | `string` | optional | |
| `notes` | `text` | optional | |

**Planned V2:** Add `user_id` FK, `status` enum lifecycle, tracking/shipping fields.

---

### `users`

Authentication users via `phx.gen.auth`.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `email` | `string` | **required**, unique, max 160 | |
| `hashed_password` | `string` | | bcrypt hash |
| `confirmed_at` | `utc_datetime` | optional | Set on magic-link confirmation |

**Virtual fields (not in DB):** `password`, `authenticated_at`

---

### `users_tokens`

Session and magic-link tokens for authentication.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `user_id` | `bigint` | FK → users | |
| `token` | `binary` | | Hashed token |
| `context` | `string` | | `"session"`, `"login"`, `"change:email"` |
| `sent_to` | `string` | optional | Email the token was sent to |
| `authenticated_at` | `utc_datetime` | optional | |

**Token validity:** Sessions: 14 days, Magic links: 15 minutes, Email changes: 7 days.

---

### `user_bikes`

A user's registered motorcycle in their garage. Junction between `users` and `bikes`.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `user_id` | `bigint` | FK → users, cascade delete | |
| `bike_id` | `bigint` | FK → bikes | Optional — can register without selecting a model |
| `nickname` | `string` | optional | User's name for their bike |
| `bike_image_url` | `string` | optional | Legacy — validated URL format |

**Relationships:**
- `belongs_to :user`
- `belongs_to :bike`
- `has_many :images` (UserBikeImage)
- `has_many :mods` (UserBikeMod)

---

### `user_bike_images`

User-uploaded photos stored on Cloudflare R2.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `user_bike_id` | `bigint` | FK → user_bikes, cascade delete | |
| `url` | `string` | **required** | Public R2 URL |
| `storage_key` | `string` | optional | R2 object key (for deletion) |
| `position` | `integer` | default: `0` | Display/carousel order |

---

### `user_bike_mods`

Rider modifications tracked per bike with cost, rating, and optional embedding for semantic search.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | `bigint` | PK | |
| `user_bike_id` | `bigint` | FK → user_bikes, cascade delete | |
| `mod_type` | `enum` | **required** | See enum values below |
| `description` | `text` | **required**, 3–500 chars | What was done |
| `brand` | `string` | optional, max 100 | Manufacturer/brand |
| `cost_cents` | `integer` | optional, ≥ 0 | Cost in cents (displayed as dollars in UI) |
| `installed_at` | `date` | optional | Installation date |
| `rating` | `integer` | optional, 1–5 | User satisfaction rating (5-star UI) |
| `position` | `integer` | default: `0` | Display order |
| `embedding` | `vector(768)` | optional | ⚡ pgvector — for future semantic search |

**`mod_type` enum values:** `exhaust`, `gearing`, `suspension`, `clutch`, `engine`, `electronics`, `intake`, `controls`, `tires`, `protection`, `lighting`

---

## Relationship Summary

| Parent | Child | Type | FK Column | On Delete |
|--------|-------|------|-----------|-----------|
| `engines` | `bikes` | 1 → many | `bikes.engine_id` | — |
| `bikes` | `chassis_specs` | 1 → one | `chassis_specs.bike_id` | — |
| `bikes` | `dimensions` | 1 → one | `dimensions.bike_id` | — |
| `bikes` | `bike_features` | 1 → many | `bike_features.bike_id` | — |
| `bikes` | `images` | 1 → many | `images.bike_id` | — |
| `bikes` | `descriptions` | 1 → many | `descriptions.bike_id` | — |
| `bikes` | `orders` | 1 → many | `orders.bike_id` | — |
| `users` | `users_tokens` | 1 → many | `users_tokens.user_id` | cascade |
| `users` | `user_bikes` | 1 → many | `user_bikes.user_id` | cascade |
| `bikes` | `user_bikes` | 1 → many | `user_bikes.bike_id` | — |
| `user_bikes` | `user_bike_images` | 1 → many | `user_bike_images.user_bike_id` | cascade |
| `user_bikes` | `user_bike_mods` | 1 → many | `user_bike_mods.user_bike_id` | cascade |

---

## Indexes

| Table | Index | Type |
|-------|-------|------|
| `bikes` | `slug` | unique |
| `users` | `email` | unique (citext) |
| `users_tokens` | `[user_id]` | btree |
| `users_tokens` | `[context, token]` | unique |
| `user_bikes` | `[user_id]` | btree |
| `user_bike_images` | `[user_bike_id]` | btree |
| `user_bike_mods` | `[user_bike_id]` | btree |

---

## Enums (Postgres)

| Enum Name | Values | Used By |
|-----------|--------|---------|
| `bike_status` | `street_legal`, `competition` | `bikes.status` |
| `bike_category` | `adv`, `rally`, `mx` | `bikes.category` |
| `weight_type` | `dry`, `curb` | `dimensions.weight_type` |
| `description_kind` | `marketing`, `maintenance` | `descriptions.kind` |
| `mod_type` | `exhaust`, `gearing`, `suspension`, `clutch`, `engine`, `electronics`, `intake`, `controls`, `tires`, `protection`, `lighting` | `user_bike_mods.mod_type` |

---

## Vector Columns (pgvector)

| Table | Column | Dimensions | Model | Status |
|-------|--------|-----------|-------|--------|
| `descriptions` | `embedding` | 768 | OpenAI `text-embedding-3-small` | Schema exists, not yet populated |
| `user_bike_mods` | `embedding` | 768 | OpenAI `text-embedding-3-small` | Schema exists, not yet populated |

---

## Contexts → Tables Mapping

| Context Module | Tables Managed |
|---------------|----------------|
| `Kove.Bikes` | `bikes`, `engines`, `chassis_specs`, `dimensions`, `bike_features`, `images`, `descriptions` (read-only) |
| `Kove.Accounts` | `users`, `users_tokens` |
| `Kove.UserBikes` | `user_bikes`, `user_bike_images`, `user_bike_mods` |
| `Kove.Storage` | External: Cloudflare R2 (referenced by `user_bike_images.storage_key`) |

---

## Migration History (15 migrations)

| # | Timestamp | Name | Description |
|---|-----------|------|-------------|
| 1 | `20260301220431` | `enable_pgvector` | Enables pgvector extension |
| 2 | `20260301220444` | `create_engines` | Engine platform table |
| 3 | `20260301220445` | `create_bikes` | Core bike table with enums |
| 4 | `20260301220446` | `create_chassis_specs` | Chassis/suspension details |
| 5 | `20260301220447` | `create_dimensions` | Weight/size specs |
| 6 | `20260301220448` | `create_bike_features` | Feature list |
| 7 | `20260301220449` | `create_images` | Product images |
| 8 | `20260301220450` | `create_descriptions` | Text descriptions + embedding |
| 9 | `20260301220451` | `create_orders` | Basic order capture |
| 10 | `20260309000001` | `fix_mx450_engine_id` | Data fix for MX 450F |
| 11 | `20260309000002` | `resize_description_embedding` | Change embedding from 1536 → 768 dims |
| 12 | `20260309210218` | `create_users_auth_tables` | `phx.gen.auth` users + tokens |
| 13 | `20260309212500` | `create_user_bikes` | User garage registration |
| 14 | `20260309220000` | `create_user_bike_images` | User photo uploads (R2) |
| 15 | `20260310030706` | `create_user_bike_mods` | Rider modifications + mod_type enum |
