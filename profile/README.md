# FG-CollectLabs

Data collection, pricing intelligence, and inventory tooling for the TCG market — built end-to-end as a personal engineering project across Go APIs, Python pipelines, TypeScript SPAs, and Hugo static sites.

**[→ futuregadgetlabs.com](https://futuregadgetlabs.com)** — live hub with health checks and architecture overview

---

## What this org is

A full-stack TCG market intelligence platform I built from scratch. The goal: turn fragmented, noisy marketplace data (TCGPlayer, Manapool, eBay) into clean pricing signals that drive real sell/hold/crack decisions for sealed product.

Everything here is production software running against real data — not toy projects.

---

## Live tools

| Tool | Stack | What it does |
| --- | --- | --- |
| [EV Calculator](https://futuregadgetlabs.com/ev-calculator/) | Go · Hugo · Vanilla JS · Firebase Auth · GitHub Pages | Sealed product expected-value calculator for MTG commander precon cases. Per-card market price breakdown, platform fee modeling (TCGPlayer/eBay/Manapool), eBay File Exchange CSV export, scan-to-identify via pHash+OCR. |
| [Card Inventory](https://inventory.futuregadgetlabs.com) | Go · React/TS · Vite · PostgreSQL · Firebase Auth · Cloudflare Tunnel | Multi-tenant inventory management SaaS. Tracks box breaks, chaos-sort bin locations, grading submissions, eBay listings, and P&L. |
| [WS Set Analysis](https://fg-collectlabs.github.io/ws-set-analysis/) | Python · Claude API · MCP servers · Hugo · GitHub Pages | AI-driven Weiss Schwarz booster investment blog. Claude agent orchestrates Jikan (anime data), Yuyutei (JP preorder prices), and TCGPlayer sub-agents to produce set investment writeups. |

---

## Repos

### Market Intelligence

| Repo | Stack | Purpose |
| --- | --- | --- |
| [`market-tracker-backend`](https://github.com/FG-CollectLabs/market-tracker-backend) | **Go · pgx · sqlc · PostgreSQL · BigQuery · GCS** | Central price oracle. Weekly price snapshots for 10k+ cards across TCGPlayer and Manapool. BQ sync for analytical history. Serves batch price lookups to EV calculator and card-inventory. |
| [`sellthrough-analyzer`](https://github.com/FG-CollectLabs/sellthrough-analyzer) | **Python · Playwright · BigQuery** | Scrapes TCGPlayer and Manapool weekly, normalizes records, POSTs bulk price updates to market-tracker-backend. Also feeds BigQuery for analytical history. |
| [`market-tracker-frontend`](https://github.com/FG-CollectLabs/market-tracker-frontend) | **Vite · React 18 · TypeScript · Tailwind v3** | Dark SPA: sets index, per-set market/cards/sealed/graded ROI tabs, card price history charts, graded coverage overlay. |
| [`ev-calculator`](https://github.com/FG-CollectLabs/ev-calculator) | **Go · Hugo · Vanilla JS · Firebase Auth** | Go API serving EV reports from YAML deck configs. Hugo frontend with per-platform fee modeling, eBay CSV export, and card scan identification proxy. |

### Card Tools

| Repo | Stack | Purpose |
| --- | --- | --- |
| [`card-identifier-backend`](https://github.com/FG-CollectLabs/card-identifier-backend) | **Go · pgx · sqlc · PostgreSQL · GCS** | Card identification microservice via pHash fingerprint matching + OCR fallback. Returns ranked candidates with confidence scores. Shared by EV calculator and card-inventory. |
| [`card-identifier-frontend`](https://github.com/FG-CollectLabs/card-identifier-frontend) | **Vite · TypeScript** | Standalone image-upload UI for the card identifier API. |
| [`slab-cracker-frontend`](https://github.com/FG-CollectLabs/slab-cracker-frontend) | **Vite · TypeScript** | Card centering measurement web app. Clientside only — no backend. |
| [`slab-cracker-extension`](https://github.com/FG-CollectLabs/slab-cracker-extension) | **Chrome MV3 · TypeScript** | Companion extension: right-click region capture, PSA/CGC cert lookup, CORS-restricted fetches. |

### Investment Analysis

| Repo | Stack | Purpose |
| --- | --- | --- |
| [`ws-set-analysis`](https://github.com/FG-CollectLabs/ws-set-analysis) | **Python · Claude API · MCP · Hugo · GitHub Pages** | Weiss Schwarz booster investment blog. Multi-agent system: Claude drives IP strength, EN historical, and JP price sub-agents via custom MCP servers. |
| [`anontcg-deal-analyzer`](https://github.com/FG-CollectLabs/anontcg-deal-analyzer) | **Python · Playwright · Hugo** | Deal analyzer for AnonTCG subscriber pricing. Playwright scrapes TCGPlayer sealed prices; Hugo dashboard ranks 45 products across 5 games by discount metric. |
| [`graded-regrade-tracker`](https://github.com/FG-CollectLabs/graded-regrade-tracker) | **Go · pgx · sqlc · PostgreSQL** | Buy→grade→sell P&L CLI. Tracks purchases, grading submissions, results, and sales. Joins market-tracker at report time for market context at each purchase date. |

### Inventory (In Development)

| Repo | Stack | Purpose |
| --- | --- | --- |
| [`card-inventory-backend`](https://github.com/FG-CollectLabs/card-inventory-backend) | **Go · pgx · PostgreSQL 16 · Firebase Auth · Docker** | Multi-tenant inventory SaaS API. Acquisitions (box breaks), chaos-sort bin locations, item transformations (break/grade/crack), listing sync, eBay order import. Firebase JWT auth with org-level RLS. |
| [`card-inventory-frontend`](https://github.com/FG-CollectLabs/card-inventory-frontend) | **Vite · React · TypeScript · Firebase Auth** | Inventory management SPA. Card scanning, bin management, acquisition tracking, listing workflow. |

---

## Infrastructure

All Go APIs run in Docker containers on a **Proxmox home-lab cluster** (3 nodes), exposed via **Cloudflare Tunnel** — no open inbound ports. Frontends deploy to **GitHub Pages** via GitHub Actions.

| Layer | Technology |
| --- | --- |
| APIs | Go 1.22+ · `net/http` · pgx/v5 · sqlc |
| Database | PostgreSQL 15/16 on Proxmox LXCs |
| Analytical warehouse | BigQuery + GCS |
| Ingestion | Python · Playwright · Apify |
| Auth | Firebase Google OAuth (client) + Firebase Admin JWT (server) |
| Frontends | Hugo · Vite · React 18 · TypeScript · Tailwind |
| AI / Agents | Claude API · MCP servers (custom) |
| Infra | Proxmox · Docker · Cloudflare Tunnel · GitHub Actions · Terraform (GCS/BQ/IAM) |

---

## Sister orgs

- **[FG-CollectShop](https://github.com/FG-CollectShop)** — storefront and admin SPA. Consumes pricing signals from CollectLabs.
- **[FutureGadgetCollections](https://github.com/FutureGadgetCollections)** — v1 predecessor org. Selectively being migrated.
