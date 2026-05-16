# FG-CollectLabs

Data collection and analysis tools for the TCG ecosystem — v2 of the
[FutureGadgetCollections](https://github.com/FutureGadgetCollections) toolkit.

## What this org is

FG-CollectLabs is the lab. It's where pricing, inventory, sell-through, and
market-signal pipelines live for trading card games (Magic, Pokémon, One
Piece, and whatever else is worth tracking). The goal is to turn noisy,
fragmented marketplace data into clean metrics that can drive decisions —
either directly (buy / hold / sell) or by feeding into an LLM that reasons
about timing.

This is a rebuild, not a fork. The original org grew organically and
collected a lot of single-purpose repos. v2 is opinionated:

- **Shared data shapes.** Every analyzer reads from and writes to the same
  schemas, so cross-product comparisons are cheap.
- **Sources are pluggable.** TCGPlayer, eBay, Crystal Commerce, retailer
  inventories — each one is a thin adapter. Swappable, mockable, testable.
- **Metrics over EV.** Expected-value-of-pack calculators already exist
  everywhere. The interesting questions are about *timing*: when does
  sealed go up, by how much, and what signals appear first?

## Sister orgs

- **[FG-CollectShop](https://github.com/FG-CollectShop)** — storefront and
  inventory management. Consumes signals and pricing from CollectLabs;
  exposes the public-facing store and the internal admin SPA.
- **[FutureGadgetCollections](https://github.com/FutureGadgetCollections)** —
  the v1 org. Repos are being audited and selectively migrated; expect
  nothing here to depend on it long-term.

## Repos

### Market Intelligence

| Repo | Status | Purpose |
| --- | --- | --- |
| [`sellthrough-analyzer`](https://github.com/FG-CollectLabs/sellthrough-analyzer) | active | Python ingest pipeline — scrapes TCGPlayer, normalizes data, POSTs bulk records to market-tracker-backend |
| [`market-tracker-backend`](https://github.com/FG-CollectLabs/market-tracker-backend) | active | Go API + PostgreSQL weekly price snapshots; BQ + GCS sync. Central price oracle for EV calculator and card-inventory |
| [`market-tracker-frontend`](https://github.com/FG-CollectLabs/market-tracker-frontend) | active | Vite/React/TS dark SPA — sets index, set detail (market/cards/sealed/graded ROI tabs), card price history |
| [`ev-calculator`](https://github.com/FG-CollectLabs/ev-calculator) | active | Go API + Hugo frontend: sealed product EV calculator, pulls live prices from market-tracker |

### Card Tools

| Repo | Status | Purpose |
| --- | --- | --- |
| [`card-identifier-backend`](https://github.com/FG-CollectLabs/card-identifier-backend) | active | Go API for card identification via pHash + OCR; metadata and pricing microservice; reused by card-inventory |
| [`card-identifier-frontend`](https://github.com/FG-CollectLabs/card-identifier-frontend) | active | Vite/TS frontend for the card identifier |
| [`slab-cracker-frontend`](https://github.com/FG-CollectLabs/slab-cracker-frontend) | scaffolding | Card centering measurement web app (Vite/TS); no backend — CORS fetches only |
| [`slab-cracker-extension`](https://github.com/FG-CollectLabs/slab-cracker-extension) | scaffolding | Chrome MV3 extension: right-click region capture, PSA/CGC cert auto-fetch |

### Investment Analysis

| Repo | Status | Purpose |
| --- | --- | --- |
| [`ws-set-analysis`](https://github.com/FG-CollectLabs/ws-set-analysis) | live | Weiss Schwarz booster investment blog + Claude agent — [fg-collectlabs.github.io/ws-set-analysis](https://fg-collectlabs.github.io/ws-set-analysis/) |
| [`anontcg-deal-analyzer`](https://github.com/FG-CollectLabs/anontcg-deal-analyzer) | active | AnonTCG subscriber ($1k coupon) deal analyzer — compares subscriber price vs TCGPlayer sealed and box-break EV; Hugo dashboard |
| [`graded-regrade-tracker`](https://github.com/FG-CollectLabs/graded-regrade-tracker) | active | Personal buy→grade→sell P&L CLI; tracks purchases, grading submissions, results, and sales; joins market-tracker for market context |

### Inventory (Planning)

| Repo | Status | Purpose |
| --- | --- | --- |
| `card-inventory-backend` | planning | Multi-tenant TCG inventory SaaS Go API — scan, chaos-sort bins, item transformations (break/grade/crack), listing sync |
| `card-inventory-frontend` | planning | Vite/TS frontend for card-inventory |
| `card-inventory-scanner` | planning | Go folder-watcher/batch ingest that calls card-identifier-backend |
| [`fg-collectlabs-infra`](https://github.com/FG-CollectLabs/fg-collectlabs-infra) | scaffolding | Terraform for shared GCS, BQ, and IAM resources |

### Org

| Repo | Status | Purpose |
| --- | --- | --- |
| [`.github`](https://github.com/FG-CollectLabs/.github) | live | Org profile and cross-repo project planning docs (`projects/`) |

## How projects connect

```
sellthrough-analyzer (Python scraper)
  │  scrapes TCGPlayer / Manapool weekly; POSTs bulk prices
  ▼
market-tracker-backend ──── PostgreSQL 192.168.86.182 (market_tracker DB)
  │  Go API — catalog, weekly snapshots, graded layer
  ├── weekly sync ──► BigQuery  (full snapshot history)
  └── weekly sync ──► GCS       (static JSON for stale consumers)
        ↑ consumed by
        ├── market-tracker-frontend  (Vite SPA, :5175)
        ├── ev-calculator            (Go API :8081 → Hugo frontend :1313)
        └── graded-regrade-tracker   (Go CLI; joins MT DB at report time)

card-identifier-backend ─── PostgreSQL 192.168.86.181 (card_identifier DB)
  │  Go API — pHash + OCR; optional price lookup from market-tracker
  ├── called by  card-identifier-frontend  (:5174)
  ├── called by  ev-calculator API         (proxied scan endpoint)
  └── will be called by  card-inventory-backend (planning)

card-inventory-backend (planning)
  │  multi-tenant: inventory, acquisitions, transformations, listings
  ├── calls  card-identifier-backend  for scan identification
  ├── calls  market-tracker-backend   for market price at acquisition
  └── nightly BQ export ─► card_inventory BQ dataset
                           (joined against price_tracker for P&L views)

slab-cracker-frontend + slab-cracker-extension  — standalone, no backend
anontcg-deal-analyzer  — Python MCPs + YAML catalog + Hugo dashboard
ws-set-analysis        — Python MCPs + Claude agent + Hugo → GitHub Pages

graded-market-watch (planning, inside market-tracker-backend)
  — PSA/CGC pop report scrapers, gem rate view, watchlist signals
```

## Infrastructure

| Layer | Where | Notes |
| --- | --- | --- |
| Go APIs | Proxmox homelab LXCs | Docker containers; market-tracker at .182, card-identifier at .181 |
| PostgreSQL | Proxmox homelab | PG 15 on Debian; credentials in `~/.config/fg-collectlabs/pg-servers.json` |
| BigQuery + GCS | GCP | Analytical warehouse + static JSON cache; sync jobs via Cloud Run Jobs |
| Frontends | Local dev / GitHub Pages | Vite dev servers locally; Hugo sites to GitHub Pages |
| Cloudflare Tunnel | homelab ingress | `*.futuregadgetlabs.com` subdomains routed into Proxmox |

Target (not yet migrated): Neon (PG branches) + Cloud Run (Go APIs) + GitHub Pages (frontends).

## Conventions

- Go for APIs and CLI tools. Python for scraping and agent orchestration. TypeScript for UIs.
- Every Go API mirrors the pattern at [`FG-CollectShop/fg-collect-core`](https://github.com/FG-CollectShop/fg-collect-core): per-repo `migrations/` + `queries/` + sqlc generation into `internal/db/dbgen/`.
- Raw scrapes are immutable; derived metrics are recomputed from raw.
- Anything that hits a paid or rate-limited API is cached aggressively and never run by accident.
- Project planning docs (architecture, decisions, TODOs) live in `.github/projects/<project>/`.
