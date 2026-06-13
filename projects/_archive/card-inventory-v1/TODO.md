# Card Inventory — TODO

> **Checkout protocol:** see [`agents/README.md`](agents/README.md). TL;DR: change `[ ]` → `[~claimed: agent-id YYYY-MM-DD]` in a single-file commit before working. Mark `[x]` when complete.
>
> **Task IDs are stable.** Never renumber. New tasks get the next free ID.
>
> **Status legend:** `[ ]` open · `[~]` claimed/in-progress · `[x]` done · `[!]` blocked · `[-]` cancelled

---

## 1. Foundation & Infrastructure

- [ ] T-001 Provision PG instance on Proxmox for `card-inventory` (dev + prod databases)
- [ ] T-002 Document PG instance in `~/.config/fg-collectlabs/pg-servers.json` and reference memory
- [ ] T-003 Create GCS buckets: `card-inventory-scans-dev`, `card-inventory-scans-prod`, `card-inventory-listing-photos-dev`, `card-inventory-listing-photos-prod` (in fg-collectlabs-infra Terraform)
- [ ] T-004 Apply 30-day lifecycle delete rule to scan buckets; no rule on listing-photo buckets
- [ ] T-005 Create BQ dataset `card_inventory` (dev + prod) (in fg-collectlabs-infra Terraform)
- [ ] T-006 Write `docker-compose.yml` for local dev (PG, optional MinIO for GCS emulation)
- [ ] T-007 Decide auth provider (D-008) and document choice
- [ ] T-008 Set up secret management approach for new repos (mirror existing pattern)
- [ ] T-009 Define environment variable conventions (`CARD_INVENTORY_*` prefix)
- [ ] T-010 Create `FG-CollectLabs/fg-collectlabs-infra` repo (skeleton scaffolded locally — see T-700 series)
- [ ] T-011 Define service accounts in Terraform: `card-inventory-backend`, `card-inventory-scanner`
- [ ] T-012 Set up Terraform remote state backend (GCS bucket for tfstate)

## 1b. Infra repo scaffolding (`fg-collectlabs-infra`)

- [ ] T-700 Local skeleton (terraform/, proxmox/, README.md) — DONE in this session if scaffold task ran
- [ ] T-701 `gh repo create FG-CollectLabs/fg-collectlabs-infra` and push initial scaffold
- [ ] T-702 Write `terraform/gcs/main.tf` for the four card-inventory buckets
- [ ] T-703 Write `terraform/bigquery/main.tf` for `card_inventory` dataset
- [ ] T-704 Write `terraform/iam/service_accounts.tf`
- [ ] T-705 Write `proxmox/pg-provisioning.md` checklist
- [ ] T-706 CI workflow: `terraform fmt` + `terraform validate` + plan-on-PR

## 2. Catalog Layer

- [x] T-020 Design `games`, `sets`, `cards`, `printings` schema (game-agnostic core)
- [x] T-021 Decide game-extensibility pattern: JSONB vs per-game side tables (D-007) — chose JSONB (`cards.attributes`)
- [ ] T-022 Build Scryfall ingest job for MTG catalog (cards + printings + sets)
- [ ] T-023 Identify Pokemon catalog source (TCGplayer? PokemonTCG.io API?) and build ingest
- [x] T-024 Define `finish` enum/lookup table (foil, etched, borderless, etc.) — `card_finish` enum in 0003_catalog.sql
- [ ] T-025 Catalog refresh strategy — daily cron? on-demand? document and implement

## 3. Identification Pipeline

- [ ] T-040 Define HTTP contract between scanner and `card-identifier-backend` (request/response shape)
- [ ] T-041 Audit existing `card-identifier-backend` API surface; gap analysis
- [ ] T-042 Add batch endpoint to identifier if missing
- [ ] T-043 Confidence threshold policy: above X auto-accept, below X needs human review
- [ ] T-044 Pgvector fallback design doc (NOT implementing yet — when phone scanning lands)

## 4. Inventory Backend (`card-inventory-backend`)

### 4a. Repo skeleton

- [ ] T-100 Create `FG-CollectLabs/card-inventory-backend` GitHub repo + push initial scaffold
- [ ] T-101 Scaffold from `FG-CollectShop/fg-collect-core` / `card-identifier-backend` reference pattern (Go + sqlc + pgx) — local skeleton scaffolded in this session
- [ ] T-102 CI/CD pipeline (mirror existing repos)
- [ ] T-103 Dockerfile + container build
- [ ] T-104 Health/ready endpoints
- [ ] T-105 Structured logging setup
- [ ] T-106 Configure linting + formatting per org standard

### 4b. Tenancy

- [ ] T-120 `orgs` + `users` + `org_memberships` schema
- [ ] T-121 Row-level security policies for tenant-scoped tables
- [ ] T-122 Auth middleware: extract `org_id` from token → set PG session var
- [ ] T-123 Org creation flow (signup → first org → owner role)
- [ ] T-124 Org invite flow (invite user → assign role)

### 4c. Inventory data model

- [x] T-140 `inventory_items` schema (printing_id, condition, status, location_id, acquisition_id, org_id)
- [x] T-141 `locations` schema (chaos-sort bins, hierarchical: box → row → slot)
- [x] T-142 `acquisitions` schema (type: break/purchase/trade, source, date, cost-at-time)
- [ ] T-143 `transactions` schema (sale events with channel, gross, fees, net)
- [ ] T-144 `listings` schema (channel, external_id, state, price, last_synced_at)
- [ ] T-145 Migration tooling chosen + scaffolded (e.g., goose, atlas — match org pattern)
- [x] T-146 Extend `acquisitions` schema: `market_price_at_acquisition`, `market_price_source` (printing/condition snapshot)
- [x] T-147 Add `inventory_items.cost_basis`, `inventory_items.created_by_transformation_id`, extend `status` enum with `consumed`
- [ ] T-148 `item_transformations` + `item_transformation_inputs` + `item_transformation_outputs` schema (per D-011)
- [ ] T-149 Recursive CTE / view to compute effective cost basis through transformation lineage
- [ ] T-150 Worker scaffolding using `SELECT … FOR UPDATE SKIP LOCKED` (per D-014)

### 4d. Inventory APIs

- [ ] T-160 `POST /inventory/items` create
- [ ] T-161 `GET /inventory/items` list with filter/search
- [ ] T-162 `PATCH /inventory/items/:id` update (location, condition, status)
- [ ] T-163 `POST /inventory/items/bulk` for scan-batch confirmation
- [ ] T-164 `POST /acquisitions` create acquisition + linked items
- [ ] T-165 `GET/POST /locations` CRUD
- [ ] T-166 `POST /transactions` record a sale → flips item status
- [ ] T-167 Search endpoint (text + filter combinator)
- [ ] T-180 `POST /transformations` — generic create (kind + inputs[] + outputs[] + cost), atomic with status flips
- [ ] T-181 `POST /transformations/sealed-break` — convenience wrapper over T-180
- [ ] T-182 `POST /transformations/grading` — submit/regrade/crack convenience wrappers
- [ ] T-183 `GET /inventory/items/:id/lineage` — full upstream + downstream walk
- [ ] T-184 Decide D-012 (cost-basis allocation default) and implement allocation function
- [ ] T-185 `ventures` schema (id, org_id, name, thesis, kind, parent_venture_id, opened_at, closed_at, status)
- [ ] T-186 Add `acquisitions.origin_venture_id` (immutable) and `inventory_items.current_venture_id` (mutable) FKs
- [ ] T-187 `venture_transfer` transformation kind: source synthetic-sale at market + destination cost-basis at market
- [ ] T-188 `POST /ventures` CRUD + close/reopen lifecycle endpoints
- [ ] T-189 `POST /ventures/:id/transfer` — move item(s) between ventures, atomic with transfer-pricing math
- [ ] T-190 `GET /ventures/:id/rollup?lens=origin|current` — venture P&L summary endpoint
- [ ] T-191 BQ view `v_venture_pnl` (cost in, sealed-at-acquisition, sealed-at-break, unrealized, realized, ROI %, ROI annualized, time-to-break, time-to-sell-p50)
- [ ] T-192 Frontend: venture list + create/edit + rollup dashboard (origin + current toggle)
- [ ] T-193 Frontend: venture transfer UI (drag item to venture / bulk reassign)

### 4f. Expenses & cash flow (D-017)

- [ ] T-194 Decide D-017a (pro-rata default basis: count / cost-in / current value) and document
- [ ] T-195 `expense_categories` lookup + seed rows
- [ ] T-196 `expenses` schema with `venture_id` + `allocation_method`
- [ ] T-197 `POST/GET/PATCH /expenses` CRUD endpoints
- [ ] T-198 Allocation function (venture_direct / pro_rata_active / unallocated) used by venture rollups
- [ ] T-199 Frontend: expense entry form + monthly expense ledger view

### 4g. Marketplace exports (D-018)

- [ ] T-200 Decide D-018a (marketplace priority order)
- [ ] T-201 `internal/exports/tcgplayer.go` adapter — Mass Listing format
- [ ] T-202 `internal/exports/manapool.go` adapter
- [ ] T-203 `internal/exports/ebay.go` adapter — File Exchange format
- [ ] T-204 `POST /exports/{marketplace}` endpoint with item filter → CSV/TSV download
- [ ] T-205 `inventory_items.listing_status` field + `listing_queued` guard against double-export
- [ ] T-206 Listing-confirmation flow: paste-back listing IDs → create `listings` row
- [ ] T-207 Frontend: bulk-select inventory → choose marketplace → download CSV

### 4h. Sealed product economics (D-019)

- [ ] T-208 `products` schema (id, set_id, kind, msrp, contents_definition jsonb)
- [ ] T-209 `product_contents` schema (slot_kind, printing_id nullable, pull_rate)
- [ ] T-210 Decide D-019a (MTG pull-rate data source) and document
- [ ] T-211 Ingest MTG sealed-product definitions for current sets in scope (Strixhaven Commander first)
- [ ] T-212 BQ view `v_product_ev` — expected gross value per product
- [ ] T-213 `acquisitions.product_id` nullable FK so a box-buy links to its product definition
- [ ] T-214 sealed_break transformation pre-populates expected outputs from `product_contents`
- [ ] T-215 Frontend: pre-purchase EV widget — paste/select a product → see EV vs MSRP

### 4i. Grading stats & grading-EV (D-020)

- [ ] T-216 `grading_stats` schema (printing_id, grading_company, grade buckets, last_refreshed_at)
- [ ] T-217 PSA pop-report scraper job (weekly cron)
- [ ] T-218 Decide D-020b (grading-fee schedule storage); implement chosen option
- [ ] T-219 BQ view `v_grading_ev` — expected value vs raw market with breakeven gem rate
- [ ] T-219a Frontend: "grading candidates" report — items in inventory with positive EV gap

### Bundles (low priority — deferred until non-Commander focus, see D-016)

### Bundles (low priority — deferred until non-Commander focus, see D-016)

- [ ] T-220 `bundle_definitions` schema slot reserved (kind, contents jsonb, premium_pct nullable)
- [ ] T-221 `inventory_items.bundle_definition_id` nullable FK; constraint: exactly one of printing_id / bundle_definition_id set
- [ ] T-222 Derived valuation function `Σ(components) × premium_pct` (defaults premium_pct=0)
- [ ] T-223 Manual-only API for creating a bundle item via merge transformation (gated, no UI v1)
- [ ] T-224 (Future) `v_set_completion` view — held / needed / shortfall
- [ ] T-225 (Future) `v_playset_breakeven` view — premium vs E[cost-to-complete] from historical sealed-break yield
- [ ] T-226 (Future) Market-tracker integration: scrape bundle prices once a thesis is validated

## 5. Scanner Service (`card-inventory-scanner`)

- [ ] T-200 Create `FG-CollectLabs/card-inventory-scanner` repo
- [ ] T-201 Folder-watcher mode: monitor a configured directory, batch on new files
- [ ] T-202 HTTP batch upload mode for future web/phone clients
- [ ] T-203 GCS upload of raw images
- [ ] T-204 Per-image call to `card-identifier-backend`
- [ ] T-205 Write `scan_batches` + `scan_results` rows in PG
- [ ] T-206 Surface ambiguous matches for review queue
- [ ] T-207 Epson V8170-specific image preprocessing (crop, rotate, deskew if needed)

## 6. Frontend (`card-inventory-frontend`)

- [ ] T-300 Create `FG-CollectLabs/card-inventory-frontend` repo
- [ ] T-301 Scaffold Vite/TS following `slab-cracker-frontend` pattern
- [ ] T-302 Auth flow integration (depends on T-007)
- [ ] T-303 Org context switcher
- [ ] T-304 Dashboard: inventory count, recent acquisitions, P&L summary
- [ ] T-305 Scan-batch review screen: confirm/correct match, set location
- [ ] T-306 Inventory browser: list, filter, search, bulk select
- [ ] T-307 Item detail view: full history, location, current value
- [ ] T-308 Virtual collection view (visual grid by set)
- [ ] T-309 Locations management UI (create bins, hierarchical)
- [ ] T-310 Acquisition entry UI (manual + scan-driven)
- [ ] T-311 Transaction recording UI (record sale)

## 7. Marketplace Integrations (v2 — placeholder, do not start in v1)

- [ ] T-400 TCGplayer API: research auth + endpoints + rate limits
- [ ] T-401 TCGplayer listing sync worker
- [ ] T-402 eBay API: research auth + endpoints + rate limits
- [ ] T-403 eBay listing sync worker
- [ ] T-404 Webhook handlers for marketplace state changes
- [ ] T-405 Listing-photo capture flow integration

## 8. Analytics

- [ ] T-500 Nightly export job: PG `inventory_items` snapshot → BQ
- [ ] T-501 Nightly export job: PG `transactions` → BQ
- [ ] T-502 BQ view joining inventory snapshots with price-tracker weekly prices
- [ ] T-503 P&L SQL view (cost basis vs current market vs sold)
- [ ] T-504 Frontend P&L panel reading from BQ via backend proxy
- [ ] T-505 (Future) BQML arbitrage-gap model — needs 6+ months of history first
- [ ] T-506 Nightly export: `item_transformations` + edge tables → BQ (flatten for analytics)
- [ ] T-507 BQ view `v_inventory_value_history` (snapshots × weekly_prices)
- [ ] T-508 BQ view `v_pnl` with recursive cost-basis resolution through transformations
- [ ] T-509 BQ view `v_price_trend` (4w/12w/26w trailing per printing)
- [ ] T-510 BQ view `v_forecast_simple` (linear/EMA naive extrapolation)
- [ ] T-511 Frontend value-over-time chart per item + per portfolio (reads `v_inventory_value_history`)
- [ ] T-512 BQ view `v_cashflows` — flatten acquisitions / transformation costs / expenses / transactions to dated signed amounts
- [ ] T-513 BQ view `v_xirr` — XIRR per scope (org / venture / acquisition); SQL or Python UDF
- [ ] T-514 BQ view `v_net_worth_over_time` — held value + cumulative cash position, weekly
- [ ] T-515 BQ view `v_inventory_summary` — rollup by location / venture / set
- [ ] T-516 BQ view `v_product_ev` (companion to T-212; ensure it is present in BQ catalog)
- [ ] T-517 BQ view `v_grading_ev` (companion to T-219; ensure it is present in BQ catalog)

### External dependencies (filed elsewhere, tracked here for visibility)

- [ ] T-518 (market-tracker repo) Expose `v_market_saturation(printing_id, week)` with `active_listings_count` + `weekly_sales_count` — see D-021
- [ ] T-519 (card-inventory) Add saturation column to decision dashboards once T-518 lands

## 9. Cross-cutting

- [ ] T-600 Per-repo `CLAUDE.md` with project-specific conventions
- [ ] T-601 Monitoring strategy (Grafana/Loki? match existing setup)
- [ ] T-602 Backup strategy for PG (pg_dump cron → GCS)
- [ ] T-603 README per repo with local dev setup
- [ ] T-604 Architecture diagram updates as decisions land
- [ ] T-605 Demo data seeding script (sample org with 100 cards)

---

## Parking lot (ideas, not yet tasks)

- Phone-scan PWA
- Webcam multi-card detection
- Barcode/QR for physical bins
- Public collection sharing pages (read-only links)
- Set-completion progress tracking
- Want-list / trade matching
- Grading submission tracker (link to `slab-cracker`)
- Tax-year P&L export
