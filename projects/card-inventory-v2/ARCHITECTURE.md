# Card Inventory V2 — Architecture

> **Status:** Draft v1.0 — pre-implementation
> **Replaces:** `projects/_archive/card-inventory-v1/` (archived 2026-06-13)
> **Goal:** Personal-use TCG inventory tracker — sealed product, singles, and graded cards in one app. Simple PO → inventory → sales loop with live TCGPlayer market value.

## What changed from V1

V1 was a multi-tenant SaaS blueprint with complex BQ analytics, GCS image storage, scanner microservice, and BQML. That was too much infrastructure for a personal tool. V2 is a focused personal-use app:

- No multi-tenancy (single-user, Bearer token auth)
- No BQ / GCS in v1 (just Postgres on existing Proxmox)
- No separate scanner service (existing box-break-app + graded-lister handle scanning)
- Three item shapes (sealed / singles / graded) as first-class modes, not a polymorphic catch-all
- Market value from TCGPlayer via market-tracker proxy — no custom scraping

## System diagram

```
inventory.futuregadgetlabs.com (GH Pages)
        │  REST/JSON
        ▼
inventory-api.futuregadgetlabs.com (Go, LXC, Cloudflare tunnel)
        │                        │
        ▼                        ▼
   PostgreSQL              market-tracker-backend
   (Proxmox LXC)           (existing, HTTP proxy for TCGPlayer prices)
   pg-card-inventory
```

## Repos

| Repo | Role |
|------|------|
| `FG-CollectLabs/card-inventory-backend` | Go API — mirrors `FG-CollectShop/fg-collect-core` |
| `FG-CollectLabs/card-inventory-frontend` | Vite/React/TS — GH Pages |

Existing `card-inventory-backend` and `card-inventory-frontend` repos are repurposed (history preserved, new branch).

## Directory structure

### Backend

```
card-inventory-backend/
├── cmd/api/             main.go — HTTP server :8086
├── internal/
│   ├── config/          env var loading
│   ├── db/dbgen/        sqlc-generated (do not edit)
│   ├── httpx/           middleware (auth, CORS, logging)
│   ├── sealed/          sealed item handlers + logic
│   ├── singles/         singles item handlers + logic
│   ├── graded/          graded item handlers + logic
│   ├── purchases/       purchase order handlers (shared)
│   ├── sales/           sales handlers (shared)
│   ├── breaks/          sealed → singles break event logic
│   ├── market/          market-tracker HTTP client + market_prices cache
│   └── dashboard/       P&L rollup queries
├── migrations/          *.sql, monotonic numbering
├── queries/             sqlc .sql input files
├── sqlc.yaml
├── Dockerfile
├── go.mod
└── CLAUDE.md
```

### Frontend

```
card-inventory-frontend/
├── src/
│   ├── components/      shared UI components
│   ├── modes/
│   │   ├── sealed/      sealed-specific views
│   │   ├── singles/     singles-specific views
│   │   └── graded/      graded-specific views
│   ├── purchases/       purchase order views (shared)
│   ├── sales/           sales views (shared)
│   ├── dashboard/       P&L dashboard
│   └── api/             typed API client
├── index.html
└── vite.config.ts
```

## Authentication

Single-user. Bearer token: `INVENTORY_API_TOKEN` env var on the server side. Frontend stores the token in `localStorage`. No auth UI — token is set once at setup.

Cloudflare tunnel provides HTTPS. No Cloudflare Access needed (Bearer token is sufficient for a single-user personal tool).

## URL structure

Single frontend at `inventory.futuregadgetlabs.com`. Mode is a top-level route:

```
/                     → redirect to /singles
/sealed               → sealed inventory
/singles              → singles inventory
/graded               → graded inventory
/purchases            → purchase orders (all modes)
/sales                → sales history (all modes)
/dashboard            → P&L summary
```

## Market value integration

**Source:** `market-tracker-backend` HTTP endpoint. The market-tracker already polls and caches TCGPlayer market prices for MTG/Pokémon sets — inventory-api proxies through it rather than hitting TCGPlayer directly.

**Call pattern:** `GET {market_tracker_base}/v1/prices?tcgplayer_product_ids=1234,5678` → batch lookup.

**Local cache:** `market_prices` table in inventory Postgres. TTL 24h. A background goroutine (ticker every 4h) refreshes any `tcgplayer_product_id` currently in `in_stock` or `listed` items.

**For graded:** PSA/CGC graded cards have their own TCGPlayer product IDs (e.g., "Charizard PSA 10" is a distinct SKU). Same mechanism.

**Display value:** `current_market_value = market_prices.market_price`. P&L = `sale_price − cost_basis − platform_fees − shipping_out`.

## Break events (sealed → singles)

When a sealed box is cracked:
1. User clicks "Break" on a sealed item → opens break modal
2. Modal: enter break date, link to box-break-app CSV (drag-drop)
3. Backend reads CSV → creates `singles_items` rows each with `break_id` FK
4. Sealed item's `qty` decremented (or status → `broken` if qty reaches 0)

`breaks` table records the linkage so sealed item's cost basis can be apportioned to singles for break P&L.

## P&L calculation

All calculated server-side in Go, returned as JSON:

```
Realized P&L  = Σ(sale.net_proceeds - item.cost_basis)   across sold items
Unrealized P&L = Σ(market_prices.market_price - item.cost_basis)  across in_stock items
Total invested = Σ(po.total_paid) across all POs
```

Break P&L: sealed item's `cost_per_unit` is split equally across all singles from that break (or user overrides). Displayed separately on the dashboard as "Break ROI."

## Postgres instance

`pg-card-inventory` on Proxmox (per `~/.config/fg-collectlabs/pg-servers.json`). Same instance as v1. New database: `card_inventory_v2`.

## Deploy

Backend: Docker container on LXC 109 (same as ev-calculator pattern). `docker run` with `EV_`-style env vars. Cloudflare tunnel at `inventory-api.futuregadgetlabs.com`.

Frontend: GH Pages via `deploy.yml`. Custom domain `inventory.futuregadgetlabs.com`.

## Reference architecture

Mirrors `FG-CollectShop/fg-collect-core`: Go + pgx + sqlc, chi router, goose migrations, per-domain `internal/` package per capability. See that repo for the handler/service/query layer pattern.
