# Card Inventory — Architecture

> **Status:** Draft v0.1 — pre-implementation
> **Codename:** `card-inventory` (brand name TBD post-launch)
> **Goal:** Multi-tenant SaaS for trading card inventory management. Self-hosted competitor to SwiftSort. Solo build, designed to be sold as SaaS later.

## North-star feature set

1. **Scan** — ingest images of cards (Epson V8170 flatbed first; phone/webcam later) and identify them.
2. **Inventory** — store cards in a chaos-sort system with location/bin tracking, condition, acquisition cost.
3. **Invest** — every item carries cost-basis + market-at-acquisition; current value derived from market-tracker; lineage preserved across transformations so P&L is always recoverable.
4. **Transform** — model the physical lifecycle: sealed → singles, raw → graded, graded → regraded, graded → cracked. One transformation primitive, not four.
5. **List** — actively manage TCGplayer + eBay listings; app is source of truth.
6. **Browse** — virtually browse the collection, search, filter.
7. **Analyze** — P&L, value-over-time, sell-timing signals, arbitrage detection, simple forecasts (joins external price-tracker data in BQ).

## System diagram

```
                                 ┌─────────────────────────┐
                                 │   card-inventory-       │
                                 │   frontend (Vite/TS)    │
                                 └────────────┬────────────┘
                                              │ REST/JSON
                                              ▼
┌──────────────────────┐         ┌─────────────────────────┐
│ card-inventory-      │  HTTP   │   card-inventory-       │
│ scanner (Go)         │────────▶│   backend (Go)          │
│ (folder watcher /    │         │                         │
│  batch ingest)       │         │   - tenants/orgs        │
└──────────┬───────────┘         │   - inventory_items     │
           │                     │   - locations / bins    │
           │ HTTP                │   - transactions        │
           ▼                     │   - listings            │
┌──────────────────────┐         └────┬───────────┬────────┘
│ card-identifier-     │              │           │
│ backend (Go)  [exist]│              │           │
│   pHash + OCR        │              │           │
│   (+ pgvector later) │              │           │
└──────────────────────┘              │           │
                                      ▼           ▼
                              ┌─────────────┐  ┌─────────────┐
                              │ PostgreSQL  │  │ GCS         │
                              │ (Proxmox)   │  │ scan/listing│
                              │             │  │ images      │
                              │ - catalog   │  │ + lifecycle │
                              │ - inventory │  └─────────────┘
                              │ - listings  │
                              │ - txns      │
                              └──────┬──────┘
                                     │ nightly export
                                     ▼
                              ┌─────────────┐         ┌─────────────────────┐
                              │ BigQuery    │◀────────│ price-tracker       │
                              │             │ weekly  │ (separate project)  │
                              │ inventory + │ prices  └─────────────────────┘
                              │ sales facts │
                              │ + price hist│
                              └─────────────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │ BQML / SQL  │
                              │ analytics   │
                              │ (P&L,       │
                              │  arbitrage) │
                              └─────────────┘

External integrations (v2):
  ┌──────────────┐    ┌──────────────┐
  │ TCGplayer API│    │ eBay API     │
  └──────┬───────┘    └──────┬───────┘
         └─────────┬─────────┘
                   ▼
           card-inventory-backend
           (listing sync workers)
```

## Repos

### Card-inventory project (this plan)

| Repo | Lang | Status | Role |
|------|------|--------|------|
| `card-inventory-backend` | Go | NEW | Core API, multi-tenant data layer, listing sync workers |
| `card-inventory-frontend` | Vite/TS | NEW | Web UI for scanning review, inventory browse, listing mgmt |
| `card-inventory-scanner` | Go | NEW | Folder-watcher / batch ingest service that calls card-identifier |
| `card-identifier-backend` | Go | EXISTING | pHash + OCR identification microservice (reused as-is) |
| `card-identifier-frontend` | Vite/TS | EXISTING | Standalone identifier UI (kept separate, not folded in) |
| `fg-collectlabs-infra` | Terraform | NEW | Shared cloud resources (GCS, BQ, IAM); see D-010 |

### Related but separate projects (touch the same data ecosystem)

These are independent products with their own roadmaps. They share storage layers (PG/BQ) and may exchange data, but card-inventory does **not** depend on shipping them and they do not block each other.

| Repo / Project | Status | Relationship to card-inventory |
|----------------|--------|-------------------------------|
| `market-tracker-backend` (+ analyzer + frontend) | EXISTING | Weekly TCG market price tracker. **Feeds price history into BQ**, which card-inventory joins against for P&L and arbitrage analytics. |
| `slab-cracker-frontend` + `slab-cracker-extension` | EXISTING | Grading / slab analysis tools. **Future hook:** when an inventory item is sent for grading, card-inventory can link out to a slab-cracker record. No direct data dependency in v1. |
| `sellthrough-analyzer` | EXISTING | Sell-through analytics. **Future hook:** card-inventory's transactions table could feed this. No v1 dependency. |

Mirrors the canonical `FG-CollectShop/fg-collect-core` Go API pattern: per-repo `migrations/` + `queries/` + sqlc generation into `internal/db/dbgen/`. See D-010.

## Repo structure (org-wide layout)

```
FG-CollectLabs/                              ← GitHub org
├── .github/                                 ← org meta + cross-repo planning (THIS repo)
│   ├── profile/README.md                    ← org profile page
│   └── projects/
│       └── card-inventory/                  ← this project's planning docs
│           ├── ARCHITECTURE.md
│           ├── TODO.md
│           ├── DECISIONS.md
│           └── agents/README.md
│
├── fg-collectlabs-infra/                    ← NEW: shared cloud resources only
│   ├── terraform/
│   │   ├── gcs/                             ← bucket creation + lifecycle rules
│   │   ├── bigquery/                        ← datasets + views + IAM
│   │   └── iam/                             ← service accounts
│   ├── proxmox/
│   │   └── pg-provisioning.md               ← manual checklist (Proxmox not TF'd)
│   └── README.md
│
├── card-inventory-backend/                  ← NEW
│   ├── cmd/api/                             ← HTTP server entrypoint
│   ├── cmd/workers/                         ← background workers (BQ export, listing sync)
│   ├── internal/
│   │   ├── config/                          ← env var loading
│   │   ├── db/dbgen/                        ← sqlc-generated (do not edit)
│   │   ├── httpx/                           ← shared HTTP middleware
│   │   ├── tenants/                         ← orgs, users, memberships
│   │   ├── catalog/                         ← cards/printings/sets read API
│   │   ├── inventory/                       ← inventory_items domain
│   │   ├── locations/                       ← chaos-sort bins
│   │   ├── acquisitions/                    ← break/purchase/trade events
│   │   ├── transactions/                    ← sales
│   │   ├── listings/                        ← marketplace listing state (v2)
│   │   ├── identify/                        ← client for card-identifier-backend
│   │   ├── gcs/                             ← image storage client
│   │   └── bqexport/                        ← nightly snapshot job
│   ├── migrations/                          ← *.sql, monotonic numbering
│   ├── queries/                             ← sqlc input
│   ├── sqlc.yaml
│   ├── Dockerfile
│   ├── go.mod
│   └── CLAUDE.md
│
├── card-inventory-frontend/                 ← NEW (Vite/TS, mirrors slab-cracker-frontend)
├── card-inventory-scanner/                  ← NEW (Go, folder-watcher service)
│
├── card-identifier-backend/                 ← EXISTING
├── card-identifier-frontend/                ← EXISTING
├── market-tracker-backend/                  ← EXISTING (related, separate project)
├── slab-cracker-frontend/                   ← EXISTING (related, separate project)
├── slab-cracker-extension/                  ← EXISTING (related, separate project)
└── sellthrough-analyzer/                    ← EXISTING (related, separate project)
```

## Storage ownership

Who owns the schema / resource for what. Critical for avoiding duplicate work and understanding migration coordination.

### PostgreSQL tables

All inside the same PG instance (`pg-card-inventory` on Proxmox), but each table's DDL lives in **the repo whose service owns writes**:

| Table | DDL owner repo | Writer service |
|-------|----------------|----------------|
| `orgs`, `users`, `org_memberships` | `card-inventory-backend` | inventory backend |
| `inventory_items` | `card-inventory-backend` | inventory backend |
| `locations` | `card-inventory-backend` | inventory backend |
| `acquisitions` | `card-inventory-backend` | inventory backend |
| `transactions` | `card-inventory-backend` | inventory backend |
| `listings` | `card-inventory-backend` | inventory backend |
| `item_transformations`, `item_transformation_inputs`, `item_transformation_outputs` | `card-inventory-backend` | inventory backend |
| `ventures` | `card-inventory-backend` | inventory backend |
| `bundle_definitions` *(deferred)* | `card-inventory-backend` | inventory backend |
| `expenses`, `expense_categories` | `card-inventory-backend` | inventory backend |
| `products`, `product_contents` | `card-inventory-backend` | inventory backend (catalog ingest) |
| `grading_stats` | `card-inventory-backend` | inventory backend (pop-report scrape job) |
| `games`, `sets`, `cards`, `printings` (catalog) | `card-inventory-backend` | inventory backend (catalog ingest job) |
| `scan_batches`, `scan_results` | `card-inventory-scanner` | scanner |

If a service needs to **read** a table owned by another service, it queries the same DB through a read-only DB user with appropriate grants — but does NOT define the schema. Schema duplication = drift.

### Cloud resources

Owned by `fg-collectlabs-infra` (Terraform):

| Resource | Purpose |
|----------|---------|
| GCS bucket `card-inventory-scans-{env}` | Raw scan images, 30d lifecycle delete |
| GCS bucket `card-inventory-listing-photos-{env}` | Curated listing photos |
| BQ dataset `card_inventory` | Analytics warehouse (snapshots + transactions) |
| BQ dataset `price_tracker` | Existing weekly price history (owned by market-tracker project — referenced, not created here) |
| Service account `card-inventory-backend@...` | Used by backend for GCS + BQ writes |
| Service account `card-inventory-scanner@...` | Used by scanner for GCS uploads |

### Proxmox PG instance

Provisioned manually per the checklist in `fg-collectlabs-infra/proxmox/pg-provisioning.md`. Connection details land in `~/.config/fg-collectlabs/pg-servers.json` (per existing reference memory).

## Storage map

### PostgreSQL (Proxmox)

**Catalog (shared, not tenant-scoped):**
- `games` — MTG, Pokemon, etc.
- `sets` — printing sets per game
- `cards` — base card identity (game, name, oracle/canonical id)
- `printings` — specific printing of a card (set, collector_number, finish, frame)
- `card_attributes_<game>` — per-game side tables for game-specific fields, OR JSONB on `cards` (decision pending — see DECISIONS.md)

**Tenancy:**
- `orgs` — tenant root
- `users` — global users
- `org_memberships` — user ↔ org with role

**Inventory (tenant-scoped, `org_id` on every row, RLS-enforced):**
- `inventory_items` — physical copies owned (printing_id **or** bundle_definition_id, condition/grade, acquisition_id, current_location_id, status, cost_basis, created_by_transformation_id, current_venture_id)
- `locations` — chaos-sort bins/boxes/binders
- `acquisitions` — break/purchase/trade events with cost-at-time, `market_price_at_acquisition` + `market_price_source` snapshot, and immutable `origin_venture_id`
- `transactions` — sales, with channel + fees + sale_price
- `listings` — active marketplace listings, source-of-truth state
- `ventures` — thesis-bound strategy groupings (id, name, thesis, kind, parent_venture_id, opened_at, closed_at, status). Kinds: `rip_and_flip`, `long_hold`, `grade_and_flip`, `sealed_appreciation`, `arbitrage`, `custom`
- `item_transformations` — header row per transformation event (kind, occurred_at, cost, notes); kinds: `sealed_break`, `grading_submit`, `grading_regrade`, `grading_crack`, `manual_split`, `manual_merge`, `venture_transfer`
- `item_transformation_inputs` — items consumed/destroyed by a transformation (item flips to `consumed`)
- `item_transformation_outputs` — items produced by a transformation (each gets `created_by_transformation_id` + an `allocated_cost_basis`)
- `bundle_definitions` *(low priority, deferred)* — playset / master-set SKU definitions (id, kind, contents jsonb of `(printing_id, qty, finish, condition_min)`). Not used for Commander v1; reserved schema slot. See D-016.
- `expenses` — standalone business expenses not tied to a specific item (mailers, eBay store sub, software, mileage). Optional `venture_id` + `allocation_method`. See D-017.
- `expense_categories` — lookup (`shipping_supplies`, `marketplace_subscription`, `storage`, `software`, `mileage`, `other`).

**Catalog (sealed-product economics — extends the existing catalog tables):**
- `products` — sealed SKUs: booster boxes, collector boosters, commander decks, bundle/gift sets (id, set_id, kind, msrp, contents_definition jsonb). See D-019.
- `product_contents` — per-slot pull rates (`product_id`, `slot_kind`, optional `printing_id` for guaranteed contents, `pull_rate`).
- `grading_stats` — population-report snapshots per printing per grading company (printing_id, company, total_graded, grade buckets, last_refreshed_at). See D-020.

**Item lifecycle (`inventory_items.status`):**
`active` → live, in your possession · `consumed` → input to a transformation, no longer physically distinct · `sold` → exited via `transactions` · `lost` / `destroyed` → terminal but unsold.

Items are never hard-deleted — lineage walks depend on consumed rows still existing.

**Venture attribution (two lenses):**
- `acquisitions.origin_venture_id` — immutable; "what strategy was this acquired under." Set once, never moves.
- `inventory_items.current_venture_id` — mutable; "what strategy is this item part of right now." Defaults from acquisition's origin venture; reassigned via a `venture_transfer` transformation, which also realizes transfer-pricing math (see D-015).

Origin lens answers "what did this $3000 of boxes ultimately produce?" Current lens answers "how is my grade-and-flip strategy performing right now?" Both views compose through the same lineage walk.

### Google Cloud Storage

- `card-inventory-scans-{env}` — raw scan batches, **30-day lifecycle delete**
- `card-inventory-listing-photos-{env}` — curated photos for active listings, longer retention

### BigQuery

- `card_inventory.inventory_snapshots` — nightly snapshot of `inventory_items` (includes `cost_basis`, `status`, `printing_id`)
- `card_inventory.transactions` — sales fact table
- `card_inventory.transformations` — nightly export of transformation graph (header + input/output edges flattened)
- joined against `price_tracker.weekly_prices` (existing) for analytics

**Derived views (no extra ETL, just SQL):**
- `v_inventory_value_history` — `inventory_snapshots` × `weekly_prices` on `(printing_id, finish, condition)` → per-item market value per week
- `v_pnl` — cost-basis vs current market vs realized sale; recursively resolves cost basis through `transformations` so a single from a busted box knows its share of box cost
- `v_venture_pnl` — per-venture rollup: cost in, sealed market at acquisition, sealed market at break, unrealized current, realized net, ROI %, ROI annualized, time-to-break, time-to-sell-p50. Supports both origin lens and current lens via a `lens` parameter
- `v_cashflows` — flat `(date, signed_amount, scope)` tuples union of acquisitions (negative), transformation costs (negative), expenses (negative, allocated per D-017), transactions.net (positive). Feeds ROI and XIRR
- `v_xirr` — XIRR per scope (`org`, `venture_id`, `acquisition_id`); computed via SQL or Python UDF over `v_cashflows`
- `v_net_worth_over_time` — weekly: held market value (from `v_inventory_value_history`) + cumulative cash position (from `v_cashflows`)
- `v_inventory_summary` — rollup of held inventory by `(org_id, location_id)`, by `current_venture_id`, by `set_id`. Powers the bin/binder/collection summary screens
- `v_price_trend` — 4w/12w/26w trailing trend per printing; baseline forecast input
- `v_forecast_simple` — naive trend extrapolation per printing (linear or EMA); upgrade to BQML when D-005 unblocks
- `v_product_ev` — expected value per sealed product from `product_contents` × current market prices. See D-019
- `v_grading_ev` — expected value of submitting a raw card for grading: `Σ(grade_rate × graded_market_price) − grading_fee − shipping`, compared to raw market price. See D-020
- `v_set_completion` *(deferred — bundles)* — held / needed / shortfall per `bundle_definition`. Not built for v1; see D-016
- `v_playset_breakeven` *(deferred — bundles)* — premium vs expected cost-to-complete from historical sealed-break yield. See D-016

Forecasting is a SQL/view concern, not new infrastructure.

**External signal dependencies (consumed, not owned):**
- Saturation / velocity per printing — expected from `market-tracker` as `v_market_saturation(printing_id, week)` exposing `active_listings_count` and `weekly_sales_count`. Card-inventory does not compute saturation. If market-tracker has not implemented this view, saturation analytics are scoped out. See D-021.

## Key architectural decisions

(See `DECISIONS.md` for the full record.)

1. **Identification:** pHash + OCR primary; pgvector embedding fallback added later when phone/webcam scanning lands. **Not** standing up Milvus/Chroma.
2. **Tenancy:** Single PG database, `org_id` discriminator, Postgres RLS. Not schema-per-tenant.
3. **Service split:** `card-identifier-backend` stays a separate microservice. Inventory backend calls it.
4. **Analytics warehouse:** BigQuery, but as the join point between the inventory app and the existing price-tracker — not as cold storage for inventory itself.
5. **Image retention:** Scans are short-lived (30d GCS lifecycle). Listing photos retained longer.
6. **Marketplace integrations:** v2, not v1. Build inventory + scan loop first.
7. **Multi-game:** game-agnostic core + per-game extension (table or JSONB; TBD).

## Data flow: transformations

```
Sealed break:
  inputs:  [sealed_box_item (status active → consumed)]
  outputs: [single_card_item × N (status active, allocated_cost_basis)]
  cost:    optional (e.g., shipping/break fee on top of original box cost)

Grading submit (raw → graded):
  inputs:  [raw_card_item (active → consumed)]
  outputs: [graded_card_item (new row, references original via transformation lineage)]
  cost:    grading service fee
  Note: graded item is a NEW inventory row, not a mutation. Regrading and cracking
        therefore work via the same primitive — see D-013.

Regrade (graded → graded):
  inputs:  [graded_card_item v1 (consumed)]
  outputs: [graded_card_item v2 (new row, new grade)]

Crack (graded → raw):
  inputs:  [graded_card_item (consumed)]
  outputs: [raw_card_item (new row, condition reset)]
```

Cost-basis allocation on outputs is the open question — see D-012. v1 default: weighted by output's market price at transformation time, with manual override.

**Queue model.** Transformations and scan ingestion use Postgres-as-queue (`SELECT … FOR UPDATE SKIP LOCKED` on a `status` column) rather than a message broker. See D-014.

## Data flow: scan-to-inventory

```
1. User drops folder of images → card-inventory-scanner
2. Scanner uploads to GCS scans bucket; creates scan_batch row in PG
3. Scanner calls card-identifier-backend per image (pHash + OCR)
4. Identifier returns candidates with confidence scores
5. Scanner writes scan_results to PG, marks ambiguous ones for review
6. User opens batch in frontend, confirms/corrects matches
7. Confirmed matches → inventory_items rows + acquisition row
8. GCS lifecycle deletes scan images after 30 days
```

## Data flow: nightly analytics

```
1. Cron job in card-inventory-backend runs at 02:00 local
2. Exports inventory_items snapshot + new transactions to BQ
3. Joins against price-tracker's weekly_prices in BQ views
4. Frontend P&L view queries BQ via backend proxy
```

## Domain glossary

| Term | Meaning |
|------|---------|
| **Org / Tenant** | A customer account; owns inventory, locations, listings |
| **Card** | Abstract card identity (e.g., "Black Lotus") |
| **Printing** | Specific physical printing (Alpha Black Lotus vs Beta Black Lotus vs Unlimited) |
| **Finish** | Foil / non-foil / etched / borderless / etc. |
| **Inventory item** | One physical copy in a tenant's possession |
| **Bin / Location** | Chaos-sort container — a box, binder, slot identifier |
| **Acquisition** | Event by which an item entered inventory (break, purchase, trade) |
| **Listing** | Active marketplace listing on TCGplayer/eBay; state mirrored in PG |
| **Chaos sort** | Storage method where items are *not* alphabetized; system tracks location instead |

## Open decisions

- Game-extensibility: JSONB vs side tables — see `DECISIONS.md#D-007`
- Auth provider: Clerk vs Auth0 vs roll-our-own — see `DECISIONS.md#D-008`
- Scanner deployment: separate service vs library imported by backend — see `DECISIONS.md#D-009`
- Cost-basis allocation method on multi-output transformations — see `DECISIONS.md#D-012`
- Bundles graduation criteria (when does manual premium % give way to market-tracker bundle prices?) — see `DECISIONS.md#D-016`
- Expense pro-rata allocation default (count, cost-in, current value?) — see `DECISIONS.md#D-017`
- Marketplace export priority order — see `DECISIONS.md#D-018`
- Pull-rate data source per game — see `DECISIONS.md#D-019`
- Pop-report scrape cadence and grading-fee schedule storage — see `DECISIONS.md#D-020`

## Reference architecture

This project mirrors the proven pattern at `FG-CollectShop/fg-collect-core`:
- Go API with sqlc + pgx
- Multi-tenant via row-level security
- Hugo-rendered docs (if applicable)
- Standard CI/CD per existing repos in this org
