# Card Inventory V2 — Architectural Decisions

---

## D-001 — One app, three modes (not three separate apps)

**Date:** 2026-06-13
**Status:** Accepted

**Context:** User originally considered three separate frontends/backends for sealed, singles, and graded.

**Decision:** One backend, one frontend, three first-class modes. Mode is a URL route and a filter on shared tables.

**Rationale:** ~80% of code (purchase orders, sales, market value joins, P&L) is identical across modes. Only the item schema shape differs. Three separate apps means the shared 80% gets written three times and evolves out of sync.

---

## D-002 — Three item tables, not one polymorphic table

**Date:** 2026-06-13
**Status:** Accepted

**Context:** Considered a single `inventory_items` table with nullable columns per mode.

**Decision:** Three tables: `sealed_items`, `singles_items`, `graded_items`.

**Rationale:** Column shapes diverge significantly (graded needs cert_number, grade, grading_co, graded_at, submitted status; singles needs finish, condition; sealed needs qty per-SKU semantics). One wide table would be a nullable mess and every query would need a `mode` discriminator anyway. Three tables give clean sqlc queries and obvious indexes. `sales` references `(mode, item_id)` as a discriminated FK — acceptable tradeoff for the join clarity gained everywhere else.

---

## D-003 — No multi-tenancy in V2

**Date:** 2026-06-13
**Status:** Accepted

**Context:** V1 was designed as multi-tenant SaaS from day one.

**Decision:** Single-user, Bearer token auth. No `org_id`, no RLS.

**Rationale:** V2 is a personal tool. Multi-tenancy adds schema complexity (RLS, org_id on every table, migration coordination) with zero benefit for a single-user app. If it ever becomes a product again, that's a V3 rewrite decision with actual users to justify it.

---

## D-004 — TCGPlayer market price via market-tracker proxy, not direct API

**Date:** 2026-06-13
**Status:** Accepted

**Context:** Options were (a) call TCGPlayer API directly, (b) proxy through market-tracker-backend, (c) punt on market value.

**Decision:** Proxy through `market-tracker-backend`. Cache results in `market_prices` table (24h TTL, background refresh every 4h for in-stock items).

**Rationale:** market-tracker already handles TCGPlayer rate limits, caching, and polling. Calling TCGPlayer directly would duplicate that infrastructure and add an API key management concern. The local cache means the frontend never blocks on an upstream call — it always reads from Postgres.

---

## D-005 — Graded market value uses TCGPlayer graded product IDs

**Date:** 2026-06-13
**Status:** Accepted

**Context:** Graded cards could be valued via (a) TCGPlayer graded-card product IDs, (b) eBay sold comps, (c) PSA population report model.

**Decision:** TCGPlayer product IDs only, same as singles/sealed. Fallback to `raw_tcgplayer_product_id` if no graded-specific product ID exists.

**Rationale:** Keeps market value integration uniform across all three modes — one `market_prices` table, one refresh goroutine, one client. eBay sold comps are more accurate for graded cards but require a separate scraping pipeline (Apify or market-tracker extension). That's a V2.1 upgrade, not a V1 blocker.

---

## D-006 — No BQ / GCS in V1

**Date:** 2026-06-13
**Status:** Accepted

**Context:** V1 architecture called for nightly BQ exports and GCS scan image storage.

**Decision:** Postgres only for V1.

**Rationale:** BQ and GCS add infrastructure complexity (IAM, service accounts, bucket lifecycle, export jobs) that doesn't pay off until there's historical data worth analyzing. The P&L dashboard can be entirely Postgres queries in V1. Re-evaluate when there's 6+ months of data and a concrete analytics question BQ would answer faster.

---

## D-007 — Breaks are separate table rows, not status mutations

**Date:** 2026-06-13
**Status:** Accepted

**Context:** Could model a break by just setting sealed_item.status = 'broken' and creating singles.

**Decision:** `breaks` table records each break event; `singles_items.break_id` FK links singles back to the break; sealed item qty is decremented.

**Rationale:** Need to compute break ROI: `(singles sold proceeds) / sealed cost basis`. That requires knowing which singles came from which box. A bare status flag loses this lineage. The `breaks` table also records the date and quantity, enabling time-series break performance analysis later.

---

## D-008 — Sales table uses a (mode, item_id) discriminated FK, not per-mode sales tables

**Date:** 2026-06-13
**Status:** Accepted

**Context:** Could have `sealed_sales`, `singles_sales`, `graded_sales` for referential integrity, or one `sales` table with a `mode` text discriminator.

**Decision:** One `sales` table with `mode TEXT` + `item_id UUID`. No database-level FK constraint to the item tables (Postgres doesn't support polymorphic FKs natively).

**Rationale:** One `sales` table means one query for the sales history list, one P&L rollup, one CSV export. The integrity check is enforced at the application layer (handler verifies item exists before creating sale). The tradeoff — no DB-level FK — is acceptable for a personal single-user app where application-layer validation is sufficient.

---

## D-009 — Repurpose existing repos, don't create new ones

**Date:** 2026-06-13
**Status:** Accepted

**Context:** `card-inventory-backend` and `card-inventory-frontend` repos exist with V1 code.

**Decision:** Reuse the existing repos. New branch, rebuild from scratch in the same repo. V1 history is preserved in git.

**Rationale:** Avoids repo proliferation. The existing repos already have the Cloudflare tunnel config, deploy workflow, and CNAME pointing at the right subdomains. Starting from a new branch is cleaner than migrating those config files.
