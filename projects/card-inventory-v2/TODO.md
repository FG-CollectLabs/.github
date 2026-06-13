# Card Inventory V2 — Task List

> Tasks have stable IDs. Update `[ ]` → `[x]` when complete.
> Dependency order: each milestone roughly requires the previous to be wired up.

---

## M1 — Backend skeleton

- [ ] T-001 Init Go module, directory structure per ARCHITECTURE.md
- [ ] T-002 `internal/config`: load env vars (`INVENTORY_API_TOKEN`, `DATABASE_URL`, `MARKET_TRACKER_BASE_URL`, `PORT`)
- [ ] T-003 `cmd/api`: chi router, CORS, Bearer token middleware, `/v1/health` endpoint
- [ ] T-004 Goose migration runner on startup (same pattern as card-inventory-backend v1)
- [ ] T-005 sqlc config + first codegen pass (generates after M2 migrations are written)

## M2 — Schema

- [ ] T-006 Migration 001: `purchase_orders` table
- [ ] T-007 Migration 002: `sealed_items`, `singles_items`, `graded_items` tables
- [ ] T-008 Migration 003: `breaks` table
- [ ] T-009 Migration 004: `sales` table
- [ ] T-010 Migration 005: `market_prices` cache table
- [ ] T-011 Run sqlc codegen — verify all tables generate clean

## M3 — Purchase orders CRUD

- [ ] T-012 sqlc queries: list, get, create, update, delete purchase_orders
- [ ] T-013 `internal/purchases`: handler + service layer
- [ ] T-014 Routes: `GET /v1/purchase-orders`, `POST /v1/purchase-orders`, `GET /v1/purchase-orders/:id`, `PATCH /v1/purchase-orders/:id`, `DELETE /v1/purchase-orders/:id`

## M4 — Item CRUD (sealed)

- [ ] T-015 sqlc queries: list (with filters: status, game, set_code), get, create, update, delete sealed_items
- [ ] T-016 `internal/sealed`: handler + service layer
- [ ] T-017 Routes: `GET /v1/sealed`, `POST /v1/sealed`, `GET /v1/sealed/:id`, `PATCH /v1/sealed/:id`, `DELETE /v1/sealed/:id`

## M5 — Item CRUD (singles)

- [ ] T-018 sqlc queries: list (with filters: status, game, finish, condition, full-text on card_name), get, create, update, delete singles_items
- [ ] T-019 `internal/singles`: handler + service layer
- [ ] T-020 Routes: `GET /v1/singles`, `POST /v1/singles`, `GET /v1/singles/:id`, `PATCH /v1/singles/:id`, `DELETE /v1/singles/:id`

## M6 — Item CRUD (graded)

- [ ] T-021 sqlc queries: list (with filters: status, grading_co, grade, game), get, create, update, delete graded_items
- [ ] T-022 `internal/graded`: handler + service layer
- [ ] T-023 Routes: `GET /v1/graded`, `POST /v1/graded`, `GET /v1/graded/:id`, `PATCH /v1/graded/:id`, `DELETE /v1/graded/:id`

## M7 — Sales CRUD

- [ ] T-024 sqlc queries: list (all modes, with filters: mode, platform, date range), get, create sales
- [ ] T-025 `internal/sales`: handler + service layer; on create → also patches item status to `sold`
- [ ] T-026 Routes: `GET /v1/sales`, `POST /v1/sales`, `GET /v1/sales/:id`

## M8 — Market price integration

- [ ] T-027 `internal/market`: HTTP client for `{MARKET_TRACKER_BASE_URL}/v1/prices`
- [ ] T-028 sqlc queries: upsert + get market_prices rows
- [ ] T-029 Background goroutine: on startup + every 4h, collect all `in_stock`/`listed` tcgplayer_product_ids across all three item tables → batch fetch → upsert market_prices
- [ ] T-030 Attach `current_market_value` and `unrealized_pnl` to item responses (join market_prices at query time)

## M9 — Breaks

- [ ] T-031 sqlc queries: create break, list breaks for a sealed_item
- [ ] T-032 `internal/breaks`: handler — accepts `sealed_item_id`, `qty_broken`, optional CSV payload
- [ ] T-033 CSV ingest: parse box-break-app CSV export format → create singles_items with `break_id` set, apportion cost basis
- [ ] T-034 Route: `POST /v1/breaks`, `GET /v1/sealed/:id/breaks`
- [ ] T-035 On break creation: decrement `sealed_items.qty`; if qty reaches 0, set status = `broken`

## M10 — Dashboard / P&L endpoint

- [ ] T-036 sqlc queries for dashboard rollup: total invested, realized P&L, unrealized P&L, by mode and overall
- [ ] T-037 `internal/dashboard`: assemble rollup from all three item tables + sales + market_prices
- [ ] T-038 Route: `GET /v1/dashboard` → returns `{ total_invested, realized_pnl, unrealized_pnl, by_mode: { sealed: {...}, singles: {...}, graded: {...} } }`

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
