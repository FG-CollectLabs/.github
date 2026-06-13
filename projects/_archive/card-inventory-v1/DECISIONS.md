# Card Inventory — Architectural Decisions

> Lightweight ADR log. Each decision: context, options considered, choice, rationale.
> Don't rewrite history — supersede with a new entry that links back.

---

## D-001 — Identification stays pHash+OCR; pgvector as future fallback

**Date:** 2026-05-05
**Status:** Accepted

**Context:** Gemini suggested standing up Milvus or ChromaDB with CLIP/ResNet embeddings for card recognition.

**Options:**
1. Replace pHash with vector DB (Milvus/Chroma)
2. Keep pHash, add pgvector fallback layer in same Postgres
3. Status quo (pHash + OCR only)

**Decision:** Option 2 — keep existing pHash+OCR pipeline as primary. Add pgvector to existing PG when phone/webcam scanning lands and ambiguity recovery becomes necessary.

**Rationale:** Epson V8170 flatbed input has controlled lighting and consistent DPI — best-case for pHash. Catalog is bounded (~100K MTG printings, not 10M). Standing up a separate vector DB adds ops burden with no v1 benefit. pgvector lives in our existing PG, no new infrastructure. Vector embeddings earn their slot for phone scanning and printing-disambiguation, both v2 problems.

---

## D-002 — Tenancy: shared DB with org_id + RLS

**Date:** 2026-05-05
**Status:** Accepted

**Context:** Multi-tenant from day one, even though only the founder uses it initially.

**Options:**
1. Single PG database, `org_id` discriminator on every tenant-scoped table, Postgres row-level security
2. Schema-per-tenant
3. Database-per-tenant

**Decision:** Option 1.

**Rationale:** Cheapest, simplest, what ~95% of SaaS does. RLS gives defense in depth. Schema-per-tenant only justified if a customer demands hard isolation, which can be migrated to later if needed.

---

## D-003 — `card-identifier-backend` stays a separate microservice

**Date:** 2026-05-05
**Status:** Accepted

**Options:**
1. Keep card-identifier as its own service; inventory backend calls it
2. Fold identifier into inventory backend as a Go package

**Decision:** Option 1.

**Rationale:** Identifier already exists, has clean boundary, may be reused by other future projects. Folding it in would be a step backward.

---

## D-004 — BigQuery as cross-app analytics warehouse, not inventory cold storage

**Date:** 2026-05-05
**Status:** Accepted

**Context:** Gemini suggested nightly PG → BQ export to make BQ the cold-storage analytics layer.

**Decision:** Use BQ, but framed differently: it's the **join point** between the inventory app and the existing weekly price-tracker (separate project). Inventory app exports nightly snapshots + transactions; BQ views join against price history for P&L and trend analysis. PG remains source of truth for operational inventory data.

**Rationale:** Inventory app's operational queries don't need historical price history — it just needs latest-cached value per item. BQ shines when joining against the already-existing price dataset.

---

## D-005 — BQML deferred until 6+ months of inventory history exist

**Date:** 2026-05-05
**Status:** Accepted

**Decision:** No BQML in v1. Revisit after 6+ months of operational inventory + transaction data.

**Rationale:** Arbitrage / sell-timing models need real training data. Building the model before there's history is premature optimization.

---

## D-006 — Scan images deleted after 30 days

**Date:** 2026-05-05
**Status:** Accepted

**Decision:** Raw scan images go to GCS with 30-day lifecycle delete. Listing photos (curated, used for marketplace) live in a separate bucket with longer retention.

**Rationale:** Storage cost is negligible per scan but unbounded growth shape kills you at scale. Identification metadata is permanent in PG; the source image becomes useless once identified. Listing-photo workflow can re-scan or upload separately when needed.

---

## D-007 — Game-extensibility pattern (JSONB vs side tables)

**Date:** 2026-05-05
**Status:** OPEN

**Context:** Different games have wildly different fields (mana cost vs HP, planeswalker abilities vs Pokemon attacks).

**Options:**
1. JSONB column on `cards` for game-specific attributes
2. Per-game side tables (`card_attributes_mtg`, `card_attributes_pokemon`)
3. Hybrid — common fields in JSONB, heavy-query fields in side tables

**Pending:** decide before T-020/T-021. JSONB is faster to build but harder to query relationally. Side tables are stricter but more migration churn per new game.

**Lean:** JSONB for v1, promote heavy-query fields to side tables when needed.

---

## D-008 — Auth provider

**Date:** 2026-05-05
**Status:** OPEN

**Options:**
1. Clerk
2. Auth0
3. Supabase Auth
4. Roll-our-own (sessions + Argon2)

**Pending.** Decide before T-007 / T-122 / T-302.

---

## D-010 — Per-repo migrations + small shared infra repo

**Date:** 2026-05-05
**Status:** Accepted

**Context:** Need to decide where DDL, migrations, and cloud-resource definitions live across the project's multiple repos.

**Options:**
1. Centralized infra/DDL repo (pseudo-terraform monorepo for all schemas + infra)
2. Hybrid: per-repo migrations + small `fg-collectlabs-infra` repo for cross-cutting cloud resources
3. Pure per-repo: each repo owns its own migrations and any infra it needs; no shared infra repo

**Decision:** Option 2.

**Rationale:**
- Matches the existing org pattern: `card-identifier-backend` and `FG-CollectShop/fg-collect-core` already use per-repo `migrations/` + `queries/` + sqlc generating into `internal/db/dbgen/`. Consistency wins.
- Atomic feature PRs require code + schema in the same repo. sqlc workflow demands migrations live next to the queries that consume them.
- Cross-cutting cloud resources (GCS buckets, BQ datasets, IAM, service accounts) genuinely don't have a single owning service — putting them in a shared `fg-collectlabs-infra` repo gives them a clean home with auditable Terraform state.
- Proxmox PG provisioning stays manual (Proxmox isn't reasonably terraformable in the current setup); the infra repo just hosts the checklist + connection inventory.

**Implications:**
- One service = one repo = one migrations directory. If service A reads service B's tables, it does so through a DB user with read grants, not by redefining the schema.
- `fg-collectlabs-infra` is small and stays small. If it grows large, that's a smell — likely something belongs in a service repo.

---

## D-011 — Item transformations modeled as one graph primitive

**Date:** 2026-05-07
**Status:** Accepted

**Context:** Items change form: sealed boxes get broken into singles, raw cards get graded, graded cards get regraded or cracked back to raw. The investment view requires that cost basis and lineage survive every transformation.

**Options:**
1. Special-case each transition (separate `breaks`, `gradings`, `regradings` tables)
2. One generic transformation table with typed `kind` + N inputs + N outputs
3. In-place mutation on `inventory_items` (e.g., flip `is_graded` true)

**Decision:** Option 2.

**Schema sketch:**
- `item_transformations` (`id`, `org_id`, `kind`, `occurred_at`, `cost`, `notes`)
- `item_transformation_inputs` (`transformation_id`, `inventory_item_id`)
- `item_transformation_outputs` (`transformation_id`, `inventory_item_id`, `allocated_cost_basis`)
- `inventory_items.created_by_transformation_id` nullable FK
- `inventory_items.status` extended with `consumed`

**Rationale:**
- Single primitive handles every present and likely-future case (sealed-break, grading, regrade, crack, manual split/merge for partial trades).
- Lineage walks naturally — recursive CTE from a single back to its original sealed product.
- In-place mutation (Option 3) destroys regrade history and breaks cost-basis recovery — non-starter.
- Per-kind tables (Option 1) duplicate effort and fragment queries.

**Implications:**
- Items are never hard-deleted; consumed rows must persist for lineage.
- All cost-basis math is recursive: a single's effective basis = its `allocated_cost_basis` chained back through transformation outputs to the original `acquisition.cost`.
- BQ export must flatten the graph (`transformations` + edge tables) for analytical joins.

---

## D-012 — Cost-basis allocation on multi-output transformations

**Date:** 2026-05-07
**Status:** OPEN

**Context:** When one input becomes N outputs (e.g., a $300 sealed box → 400 singles), how is the $300 + transformation cost split across outputs?

**Options:**
1. **Even split** — total / N. Simple, defensible, useless for tax/analysis when outputs vary 100× in value.
2. **Weighted by market value at transformation time** — uses `weekly_prices` at `occurred_at`. Closest to GAAP relative-fair-value allocation. Requires market data for every output at break time.
3. **Manual entry** — user types in basis per output. Maximum control, maximum tedium.
4. **Default weighted + manual override** — system computes Option 2, user can edit any row before commit.

**Lean:** Option 4. Weighted-by-market is the right default; override exists for items the price tracker doesn't cover (promos, oddities).

**Pending:** Confirm market-tracker coverage at single granularity is reliable enough to make weighted the default. If not, fall back to Option 1 default + manual override. Decide before T-180.

---

## D-013 — Grading transitions create a new inventory item, not mutate the existing one

**Date:** 2026-05-07
**Status:** Accepted

**Context:** A raw card going to PSA could either (a) gain a `grade` field on the same row or (b) become a new `inventory_items` row, with the raw row marked consumed.

**Options:**
1. Mutate `inventory_items` in place (flip `is_graded`, set `grade`)
2. New row per grading event, linked via `item_transformations` (per D-011)

**Decision:** Option 2.

**Rationale:**
- A graded slab is functionally a different SKU — different printing/condition/grade tuple, different market price curve, different storage.
- Regrading and cracking only work cleanly when each grading event is its own item — otherwise mutation history is lost the moment a card is regraded.
- Cost-basis math composes: grading fee becomes the transformation `cost`, allocated entirely to the single output.
- UX can still present "this card across all forms" by walking lineage — it's a view concern, not a schema concern.

**Implications:**
- Item detail page must surface lineage ("was raw NM → PSA 9 [2026-03] → PSA 10 regrade [2026-08]") by walking transformations.
- Consumed raw/graded rows still occupy the table; treat them as historical records, not clutter.

---

## D-014 — No message broker in v1; Postgres-as-queue for async work

**Date:** 2026-05-07
**Status:** Accepted

**Context:** Scan ingestion, identifier calls, and transformation processing are all async-ish. Tempting to reach for NATS / Pub/Sub / Redis Streams.

**Options:**
1. Real broker (NATS, Pub/Sub, Redis Streams)
2. Postgres-as-queue (`SELECT … FOR UPDATE SKIP LOCKED` on a `status` column)
3. Synchronous HTTP everywhere

**Decision:** Option 2 for queued work, Option 3 for direct identifier calls. No broker.

**Rationale:**
- Solo-builder throughput is "200 scans on a Saturday," not Kafka territory. PG-as-queue handles thousands/sec before it sweats.
- Zero new infra; transactional with domain writes (queue update + business write commit atomically).
- A broker earns its slot only when ≥2 independent consumers want the same event (e.g., listing-sync + BQ export + notifications all reacting to the same transformation). Not the case in v1.

**Trigger to revisit:** First time we want a second consumer for the same domain event, or when scan throughput sustained > 50/s.

**Implications:**
- `scan_results.status` and `item_transformations.status` carry the queue state.
- A small worker pool in `cmd/workers` polls with `FOR UPDATE SKIP LOCKED`.
- Idempotency keys on transformation handlers (defense against retries).

---

## D-015 — Ventures: thesis-bound strategy primitive with internal transfer pricing

**Date:** 2026-05-07
**Status:** Accepted

**Context:** Users (starting with the founder) run distinct strategies — "rip 10 boxes and flip the singles," "long-hold sealed for appreciation," "grade and flip Reserved List." Without a first-class grouping, ROI per strategy can only be reconstructed by date + product conventions, which falls apart the moment two parallel strategies touch the same product or items move between strategies (e.g., a single from a rip-and-flip box gets diverted to a grade-and-flip play).

**Options:**
1. Free-form tags on acquisitions/items
2. `ventures` table with single immutable FK on `acquisitions.venture_id`
3. `ventures` table with **two** FKs — immutable origin on `acquisitions`, mutable current on `inventory_items`, plus parent_venture_id for hierarchy. Cross-venture moves use a `venture_transfer` transformation that applies internal transfer pricing (synthetic realize at market for source, market-priced cost basis for destination).

**Decision:** Option 3.

**Rationale:**
- Two real lenses exist: **origin** ("what did this $3000 of boxes ultimately produce?") and **current** ("how is my grade-and-flip strategy performing right now?"). One FK serves only one lens; tags serve neither well.
- Internal transfer pricing is the standard accounting trick for nested cost centers and gives both venture rollups honest, non-double-counted P&L. Source venture realizes at market (synthetic sale at fair value); destination venture's cost basis = that market value. No new conceptual machinery — it's just a transformation kind with a market-price snapshot.
- Hierarchy (`parent_venture_id`) lets a "grade-and-flip" sub-venture nest under its parent "SHV box rip" for reporting without duplicating data.

**Implications:**
- New transformation kind `venture_transfer`: input = item leaving venture A, output = same physical card (new inventory_items row) entering venture B at market-priced cost basis. The synthetic sale price for venture A's P&L is recorded on the transformation header.
- `v_venture_pnl` exposes a `lens` parameter (`origin` | `current`) so the same view answers both questions.
- Acquisition origin is immutable — even if every descendant moves to other ventures, the box venture's "production history" stays intact.
- A venture with `closed_at` set and zero active items is reportable but immutable — historical record.

---

## D-016 — Bundles (playsets / master sets) deferred; derived valuation until graduation

**Date:** 2026-05-07
**Status:** Accepted (deferred)

**Context:** Future use case: rip enough boxes to assemble a playset / master set, then sell the bundle for a premium vs the sum of its singles. Need to (a) represent the bundle as inventory, (b) value it, (c) decide if a premium exists worth ripping more boxes for. Current focus is Commander products, where playsets aren't a thing — so this is intentionally low priority.

**Options:**
1. Build full bundle support now: `bundle_definitions` catalog table, market-tracker bundle scraping, `v_set_completion`, `v_playset_breakeven`
2. Build nothing; revisit when needed
3. **Reserve the schema slot now, defer scraping and views, value bundles via `Σ(components) × user-defined premium %`**, graduate to market-tracker bundle prices once a manual eBay pass confirms a premium worth tracking

**Decision:** Option 3.

**Rationale:**
- Reserving the slot in schema (`bundle_definitions` table, `inventory_items.bundle_definition_id`) is cheap and prevents painting into a corner — the merge transformation kind already exists per D-011.
- Deferred valuation logic = derived (`Σ(components) × premium_pct`) where `premium_pct` defaults to 0 and is user-editable per bundle. Honest "I don't know what this is worth yet" default.
- Workflow when a bundle thesis appears: manual eBay search (or hand details to Claude for analysis) → confirm premium → set `premium_pct` on the bundle → eventually add bundle price tracking to market-tracker → graduate to scraped prices.
- Avoids speculative work for a use case that doesn't apply to Commander.

**Graduation triggers (revisit this decision when):**
- A non-Commander format becomes a focus (Standard/Modern/Legacy playsets, Pokemon master sets)
- Manual research confirms a stable premium worth more than ad-hoc tracking
- User has assembled ≥3 bundles and wants automated valuation

**Implications:**
- v1 ships with the table and FK but no UI for bundle creation. The merge transformation kind works but is gated behind a feature flag or manual-only API.
- `v_set_completion` and `v_playset_breakeven` are scoped out of v1.
- Market-tracker has no obligation to track bundle prices in v1.

---

## D-017 — Expenses, cash flow, and XIRR

**Date:** 2026-05-07
**Status:** Accepted (default allocation method OPEN)

**Context:** ROI is incomplete without (a) standalone business expenses (mailers, eBay store sub, software, mileage) and (b) honest time-weighted return math. XIRR is the right metric for cash flows that arrive irregularly across acquisitions, breaks, and sales.

**Decision:**
- Add `expenses` table for non-item-tied costs with optional `venture_id` and `allocation_method` (`venture_direct`, `pro_rata_active`, `unallocated`).
- Add `v_cashflows` view: union of acquisitions (negative), transformation costs (negative), expenses (negative, allocated), transactions.net (positive). Filterable by org / venture / acquisition.
- Add `v_xirr` for time-weighted return per scope and `v_net_worth_over_time` for held-value-plus-cash trend.

**Schema:**
```
expenses (
  id, org_id, incurred_at date, amount numeric,
  category_id fk → expense_categories,
  vendor text, notes text,
  venture_id fk nullable,
  allocation_method enum('venture_direct','pro_rata_active','unallocated')
)
expense_categories (
  id, key text unique, label text
)  -- seeded: shipping_supplies, marketplace_subscription, storage,
   --         software, mileage, other
```

**Allocation semantics:**
- `venture_direct` — full amount lands on `venture_id`. Use for "this $40 of mailers was for the SHV box rip."
- `pro_rata_active` — divided across active ventures at the rollup time. Use for "eBay store sub this month."
- `unallocated` — sits at org level only. Use for one-off overhead you don't want polluting venture P&L.

**Open (D-017a):** default split basis for `pro_rata_active` — by venture count, by cost-in, or by current held value? Lean = current held value (the venture using the most "shelf space" pays the most overhead). Decide before T-194.

**Rationale:**
- XIRR needs nothing more than `(date, signed_amount)` tuples per scope. The flatten-everything-to-cashflows view is a 50-line SQL union, not new infrastructure.
- Three allocation methods cover the realistic cases without overengineering. Default to `unallocated` so users don't accidentally smear overhead.
- Net worth chart is the single most motivating dashboard for a solo collector-investor — falls out for free once cash flows + held value coexist in BQ.

---

## D-018 — Marketplace export adapters

**Date:** 2026-05-07
**Status:** Accepted (priority order OPEN)

**Context:** Listings on TCGplayer / eBay / Manapool are the actual revenue path. Each marketplace expects a different CSV/TSV format. Building this once, well, is required to close the rip-to-revenue loop.

**Decision:**
- One adapter per marketplace under `internal/exports/{tcgplayer,ebay,manapool}.go`.
- `POST /exports/{marketplace}` with item filter → returns CSV/TSV. Items mark as `listing_queued` so they don't get double-exported.
- When marketplace returns a confirmation (manual paste of listing ID, or future webhook), create/update the corresponding `listings` row.
- Photo upload is **out of scope** for v1 export — those workflows are marketplace-specific (TCG seller portal, eBay File Exchange + photo URL, Manapool drag-and-drop) and easier to do natively per marketplace at first.

**Open (D-018a):** which marketplace ships first? Lean = **TCGplayer** (largest TCG-singles audience, most mature mass-listing format) → **Manapool** (newer, simpler, growing) → **eBay** (most format quirks, slowest to integrate). Decide before T-201.

**Rationale:**
- Adapter-per-marketplace keeps marketplace-specific column quirks isolated. No premature abstraction over a "universal listing format" — every marketplace has a unique field that breaks the abstraction.
- Marking items `listing_queued` is the minimum guard against double-listing without committing to two-way sync (which is a v2 feature).
- Photo upload deferral keeps v1 scope honest. Sellers already do this manually today.

---

## D-019 — Sealed-product contents and pack EV

**Date:** 2026-05-07
**Status:** Accepted (data source per game OPEN)

**Context:** Deciding "is this booster box worth buying" requires knowing what's inside it and the market value of that distribution. This is the highest-strategic-value piece of the analytics layer — it directly informs venture creation.

**Decision:**
- `products` table for sealed SKUs (booster box, collector booster, commander deck, bundle/gift set, prerelease pack).
- `product_contents` table: per-slot expected pull, with `pull_rate` (probability per pack/box) and optional `printing_id` for guaranteed contents (e.g., commander deck precons).
- `v_product_ev(product_id)` view: `Σ(slot_pull_rate × printing_market_price) × packs_per_unit`, returns expected gross value vs MSRP.
- An acquisition of a sealed product can link to `products.id`; the sealed_break transformation reads `product_contents` to seed expected outputs.

**Open (D-019a):** pull-rate data source per game.
- MTG: WotC publishes some, MTGStocks-style aggregation, community-curated tables (e.g., box content guides). Lean = bootstrap with community data, allow user override per `product_contents` row.
- Pokemon: less canonical; community pull rate datasets exist.
- Decide per-game before ingesting. Acceptable to ship MTG only in v1 since first set is Strixhaven Commander.

**Rationale:**
- One product table covers boxes, collector boosters, commander decks (guaranteed contents = pull rate of 1.0), and prerelease packs uniformly.
- Pull-rate-driven EV is what makes "rip vs hold sealed" decisions defensible.
- Allowing per-row overrides means the user can correct community data when WotC changes a print run mid-set without waiting for a community update.

**Implications:**
- The sealed-break transformation can pre-populate output items as a checklist — "you should have gotten ~1 mythic, ~3 rares, etc." — and flag pulls that deviate, useful for both audit and refining pull-rate estimates over time.

---

## D-020 — Grading stats and grading-EV

**Date:** 2026-05-07
**Status:** Accepted (scrape cadence + fee storage OPEN)

**Context:** Deciding whether to send a raw card to PSA depends on the gem rate (probability of PSA 10), the price spread between raw and graded, and grading + shipping fees. Without pop-report data, grade-and-flip is gut feel.

**Decision:**
- `grading_stats` table per `(printing_id, grading_company)`: total_graded, per-grade buckets (10 / 9 / 8 / 7 / lower), `last_refreshed_at`. Snapshot model — overwrite on refresh.
- Scrape PSA pop reports (public data, legal). Initial focus PSA; add CGC / BGS later if relevant.
- `v_grading_ev(printing_id, raw_condition)` view: `Σ(grade_rate × graded_market_price) − grading_fee − shipping`, compared to raw market price → return delta and breakeven gem rate.
- A `grading_submit` transformation can optionally link to a target grading company; the cost is the grading fee.

**Schema sketch:**
```
grading_stats (
  printing_id fk, grading_company text,
  total_graded int,
  count_10 int, count_9 int, count_8 int, count_7_or_lower int,
  raw_url text,           -- where the data was scraped from
  last_refreshed_at ts,
  primary key (printing_id, grading_company)
)
```

**Open (D-020a):** scrape cadence — weekly is plenty (pop reports don't move daily). Reuse market-tracker's cron pattern.
**Open (D-020b):** grading-fee schedule storage. Options: (1) hard-coded constants per company per service tier; (2) `grading_fee_schedules` table editable per user (for grandfathered rates / bulk submissions). Lean = small lookup table; revisit if it becomes onerous.

**Rationale:**
- Pop reports are public, scrapable, and the only objective signal for gem rate available to a solo investor.
- Snapshot model is fine — we don't need PSA history; we just need the current state to drive the EV calc.
- Composes cleanly with the existing `grading_submit` transformation: the same primitive that records the act of grading also gets the EV decision support behind it.

---

## D-021 — Saturation and velocity signals are market-tracker's job

**Date:** 2026-05-07
**Status:** Accepted

**Context:** "Is this market oversaturated with sellers" and "how fast are these moving" are decision inputs the user wants. The data lives upstream of card-inventory in the marketplace itself.

**Decision:** Card-inventory does **not** compute saturation or velocity. It consumes `v_market_saturation(printing_id, week)` exposing `active_listings_count` and `weekly_sales_count` from market-tracker. If the view doesn't exist, saturation analytics are scoped out and a backlog item lives in market-tracker.

**Rationale:**
- Single source of truth for marketplace state. Two services scraping the same data is the textbook way to build drift.
- Card-inventory's job is to apply the signal to your inventory; market-tracker's job is to produce the signal.
- Keeps the dependency explicit and the schema decoupled.

**Implications:**
- A backlog item must be filed in market-tracker for the saturation view (not tracked in this repo).
- Until the upstream view exists, related card-inventory views (`v_decision_score` style aggregates) defer their saturation column.

---

## D-009 — Scanner: separate service or library

**Date:** 2026-05-05
**Status:** OPEN

**Options:**
1. Separate `card-inventory-scanner` service (current plan)
2. Go package imported by backend
3. CLI tool that pushes to backend via API

**Lean:** separate service for clean folder-watching deployment, but library is simpler for v1.
