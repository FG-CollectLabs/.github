# Market Tracker — Release Roadmap

High-level milestones. Granular task tracking lives in [TODO.md](./TODO.md).

---

## v0.1 — First Live Deployment ✅ (2026-05-18)

API live at `https://market.futuregadgetlabs.com`. Admin dashboard at `/admin`.

- Go API on LXC 109 (proxmox3), Cloudflare tunnel, PostgreSQL on LXC 106
- 10 MTG commander sets seeded: blc, soc, sos, drc, eoc, fic, lcc, ltc, tdc, tmc
- Weekly price ingest: TCGPlayer (via TCGCSV) + eBay sold (self-hosted scraper)
- Listing depth + velocity ingest: TCGPlayer + Manapool
- Per-seller listing snapshot ingest: TCGPlayer
- All four ingest jobs on Sunday cron via GitHub Actions self-hosted runner
- `POST /v1/prices/batch` — bulk display-key price lookup (used by EV calculator)
- Admin dashboard: health, sets browser, card catalog, snapshot history, depth viewer
- Docker CI: `philwin/market-tracker-backend:latest` on every push to master

---

## v0.2 — Frontend + Data Completeness

Ship the public-facing SPA and round out the data coverage.

- **Deploy market-tracker-frontend** — Vite/React SPA to GitHub Pages; `VITE_API_URL` → `market.futuregadgetlabs.com`; Cloudflare tunnel hostname `market-tracker.futuregadgetlabs.com`
- **Seed remaining sets** — all sets referenced by EV calculator (run `cmd/seed` when new sets launch)
- **eBay sold coverage** — validate eBay scraper is hitting all 10 sets; tune `EBAY_WINDOW_DAYS` to build 90-day history
- **Manapool prices** — confirm `ingest-prices` Manapool platform is writing snapshot rows alongside TCGPlayer

---

## v0.3 — Graded Data Layer

Surface PSA/CGC pop report data through the graded endpoints already wired in the API.

- **`cmd/ingest-graded`** — scrape PSA + CGC pop reports for tracked cards weekly
- **Gem rate computation** — PSA 10 / total pop, CGC 10 / total pop stored in `graded_snapshots_weekly`
- **Graded price ingest** — PriceCharting API or eBay sold filter for graded copies
- **Frontend: Graded ROI tab** — already scaffolded in `SetDetailPage`; populate with real data
- **Dashboard: Graded tab** — add to `/admin` alongside Snapshots + Depth

---

## v0.4 — Analytics Sync (BQ + GCS)

Push data out to the analytical warehouse so downstream consumers (card-inventory, BQML) can join it.

- **`cmd/sync bigquery`** — weekly append of `card_snapshots_weekly` → BQ `market_tracker.weekly_prices`
- **`cmd/sync gcs`** — weekly JSON bake per set → GCS bucket for stale-tolerant consumers
- **Deploy as Cloud Run Jobs** — Cloud Scheduler weekly trigger; network path homelab PG → Tailscale subnet router
- **`v_market_saturation` view** — expose `active_listings_count` + `weekly_sales_count` per printing per week for card-inventory analytics (see card-inventory T-518)

---

## v0.5 — V1 Decommission + Cloud Migration

Cut over fully to V2, archive V1, and optionally migrate off the homelab.

- **Migrate V1 history** — `scripts/migrate_v1.py`: map V1 TCGPlayer price JSON → V2 `display_key` → POST to `/v1/admin/cards/snapshots/bulk`
- **Update card-identifier-backend** — change `MARKET_TRACKER_URL` to `https://market.futuregadgetlabs.com`
- **Archive V1 repos** — `FutureGadgetCollections/collection-market-tracker-{backend,data,frontend-admin}`
- **Cloud migration (optional)** — Neon `main` branch for DB, Cloud Run for API, GitHub Pages for frontend; homelab LXC repurposed for preprod
