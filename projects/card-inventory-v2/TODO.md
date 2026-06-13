# Card Inventory V2 — Task List

> Tasks have stable IDs. Update `[ ]` → `[x]` when complete.
> Dependency order: each milestone roughly requires the previous to be wired up.

---

## M1 — Backend skeleton

- [x] T-001 Init Go module, directory structure per ARCHITECTURE.md
- [x] T-002 `internal/config`: load env vars (`API_TOKEN`, `DATABASE_URL`, `MARKET_TRACKER_URL`, `API_ADDR`, `CORS_ORIGINS`)
- [x] T-003 `cmd/api`: stdlib mux, CORS, Bearer token middleware, `/healthz` + `/readyz` endpoints
- [x] T-004 Goose migration runner on startup
- [x] T-005 No sqlc — using direct pgx queries (same pattern as card-inventory-backend v1)

## M2 — Schema

- [x] T-006 Migration 0001: `purchase_orders` table
- [x] T-007 Migration 0002: `sealed_items`, `singles_items`, `graded_items` tables
- [x] T-008 Migration 0003: `breaks` table + `singles_items.break_id` FK + `sales` table
- [x] T-009 (merged into 0003)
- [x] T-010 Migration 0004: `market_prices` cache table
- [x] T-011 N/A — no sqlc; direct pgx queries confirmed compile-clean

## M3 — Purchase orders CRUD

- [x] T-012 Direct pgx queries in handler
- [x] T-013 `internal/purchases/handler.go`
- [x] T-014 Routes registered: GET/POST/GET/:id/PATCH/:id/DELETE/:id

## M4 — Item CRUD (sealed)

- [x] T-015 Direct pgx queries with status/game filters + market price LEFT JOIN
- [x] T-016 `internal/sealed/handler.go`
- [x] T-017 Routes registered

## M5 — Item CRUD (singles)

- [x] T-018 Direct pgx queries with status/game/finish/condition/full-text/break_id filters
- [x] T-019 `internal/singles/handler.go`
- [x] T-020 Routes registered

## M6 — Item CRUD (graded)

- [x] T-021 Direct pgx queries with status/game/grading_co filters
- [x] T-022 `internal/graded/handler.go`
- [x] T-023 Routes registered

## M7 — Sales CRUD

- [x] T-024 Direct pgx queries with mode/platform filters
- [x] T-025 `internal/sales/handler.go`; create → tx: insert sale + UPDATE item status='sold'
- [x] T-026 Routes registered

## M8 — Market price integration

- [x] T-027 `internal/market/market.go` — HTTP client for market-tracker `/v1/prices`
- [x] T-028 Upsert in `Refresher.upsert()`
- [x] T-029 Background goroutine, startup + every 4h; collects active product IDs across all 3 tables
- [x] T-030 market_price joined via LEFT JOIN on every item list/get response

## M9 — Breaks

- [x] T-031 Direct pgx queries in breaks handler
- [x] T-032 `internal/breaks/handler.go` — create validates qty, tx: insert break + decrement sealed qty
- [ ] T-033 CSV ingest: parse box-break-app CSV → bulk create singles_items with break_id + apportioned cost basis
- [x] T-034 Routes: POST /api/v1/breaks, GET /api/v1/sealed/:sealed_id/breaks, GET /api/v1/breaks/:id
- [x] T-035 On break creation: qty decremented; status → 'broken' when qty reaches 0

## M10 — Dashboard / P&L endpoint

- [x] T-036 Direct pgx queries for per-mode rollup
- [x] T-037 `internal/dashboard/handler.go`
- [x] T-038 Route: GET /api/v1/dashboard

## M11 — Frontend skeleton

- [ ] T-039 Init Vite/React/TS project; chi/wouter routing; auth (Bearer token prompt on first load → stored in localStorage)
- [ ] T-040 Mode nav: Sealed / Singles / Graded / Purchases / Sales / Dashboard tabs
- [ ] T-041 Typed API client: `src/api/` — one function per endpoint, shared fetch wrapper with auth header
- [ ] T-042 GH Pages deploy workflow (`deploy.yml`) + CNAME `inventory.futuregadgetlabs.com`

## M12 — Frontend: Purchase Orders

- [ ] T-043 Purchase Orders list view: table with source, seller, date, total_paid, status
- [ ] T-044 Create PO form: source, seller, purchased_at, item_total, shipping_paid, platform_fees, notes
- [ ] T-045 PO detail: shows all items across modes linked to this PO

## M13 — Frontend: Sealed mode

- [ ] T-046 Sealed list view: table with product_name, game, qty, cost_per_unit, current_value, unrealized_pnl, status
- [ ] T-047 Add sealed item form: tcgplayer_product_id lookup (type-ahead against market-tracker), product_name, set_code, game, qty, cost_per_unit, link PO
- [ ] T-048 Sealed item detail: shows break history, linked singles
- [ ] T-049 "Break" action on sealed item: modal → enter qty_broken, broken_at, optionally upload box-break-app CSV

## M14 — Frontend: Singles mode

- [ ] T-050 Singles list view: table with card_name, set_name, finish, condition, cost_basis, current_value, unrealized_pnl, status; full-text search
- [ ] T-051 Add single form: tcgplayer_product_id lookup, card_name, set, finish, condition, cost_basis, link PO or break
- [ ] T-052 Bulk add via CSV import (box-break-app format)

## M15 — Frontend: Graded mode

- [ ] T-053 Graded list view: table with card_name, grading_co, grade, cert_number, cost_basis, current_value, unrealized_pnl, status
- [ ] T-054 Add graded item form: card lookup, grading_co, cert_number, grade, cost_basis, acquired_at
- [ ] T-055 "Mark graded" action: update grade + graded_at on item that was in `submitted` status

## M16 — Frontend: Sales + Dashboard

- [ ] T-056 Record sale form: mode selector, item search, platform, sold_at, sale_price, fees, shipping_out
- [ ] T-057 Sales history list: table with mode, card/product name, platform, sold_at, sale_price, net_proceeds, realized_pnl
- [ ] T-058 Dashboard: total invested / realized P&L / unrealized P&L cards, per-mode breakdown, recent sales

## M17 — Deploy

- [ ] T-059 Dockerfile for backend (same pattern as ev-calculator, single binary)
- [ ] T-060 LXC deploy on Proxmox — `docker run` with env vars; Cloudflare tunnel to `inventory-api.futuregadgetlabs.com`
- [ ] T-061 Smoke test: health check, create one PO + one item of each mode, record a sale, verify dashboard numbers
