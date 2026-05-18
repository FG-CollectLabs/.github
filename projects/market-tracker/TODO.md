# Market Tracker V2 — TODO

Goal: V2 live on Proxmox, data flowing weekly, frontend deployed.

Last audited: 2026-05-18

---

## What's actually built (as of 2026-05-18)

### Backend (`market-tracker-backend`)
- [x] Migrations 0001–0008 applied to `market_tracker` DB on 192.168.86.182
- [x] All API routes wired — no 501s: catalog, snapshots, market, listing-depth, graded, prices
- [x] `cmd/ingest-depth` — TCGPlayer + Manapool listing depth snapshots
- [x] `cmd/ingest-prices` — weekly prices via TCGCSV + Manapool
- [x] `cmd/ingest-ebay-scrape` — self-hosted eBay sold scraper (replaces Apify)
- [x] `cmd/ingest-listings` — per-seller listing snapshots
- [x] `cmd/seed` — Scryfall-backed catalog seeder
- [x] `cmd/sync` — BQ + GCS export skeleton
- [x] `.github/workflows/docker.yml` — builds + pushes `philwin/market-tracker-backend:latest` on merge to master
- [x] `.github/workflows/ingest.yml` — weekly Sunday cron (depth → prices → ebay → listings) on self-hosted runner
- [x] `deploy.sh` + `deploy/env.production.example` ready

### Frontend (`market-tracker-frontend`)
- [x] Vite + React 18 + TypeScript + Tailwind SPA at port 5175
- [x] SetsPage (`/`) — fetches `/v1/sets`, grouped by game
- [x] SetDetailPage (`/sets/:game/:code`) — 4 tabs: Market, Cards, Sealed, Graded ROI
- [x] CardDetailPage (`/cards/:displayKey`) — Price History + Graded tabs
- [x] GradedCoveragePage (`/graded`) — coverage matrix across all sets
- [x] Full API client (`lib/api.ts`) — 17 functions covering all backend endpoints
- [x] Dev proxy: `/v1` → `$VITE_API_URL` (default `localhost:8080`)

---

## Blocking: nothing is actually live

The API is not reachable (`192.168.86.199` not provisioned, `192.168.86.182:8080` not responding).
Ingest jobs are configured but have never successfully run. No catalog data exists.

---

## Phase 1 — Get the API running (main blocker)

- [ ] **Provision LXC 109 on proxmox1**
  - IP: 192.168.86.199, name: `fg-market-app`
  - 1 CPU, 512 MB RAM, 4 GB disk
  - `apt install -y docker.io`
  - Append SSH key to `/root/.ssh/authorized_keys`

- [ ] **Create env file on LXC**
  ```bash
  mkdir -p /etc/market-tracker
  # Fill in DATABASE_URL, ADMIN_API_TOKEN from pg-servers.json + openssl rand -hex 32
  ```

- [ ] **Deploy**: `cd market-tracker-backend && ./deploy.sh`

- [ ] **Verify**:
  ```
  curl http://192.168.86.199:8080/healthz  → ok
  curl http://192.168.86.199:8080/readyz   → ready
  ```

---

## Phase 2 — Seed catalog

Run against the DB directly (no live API required):

```bash
DATABASE_URL="postgres://fg_app:<pw>@192.168.86.182:5432/market_tracker?sslmode=disable" \
  go run ./cmd/seed --sets soc,sos,blc,ffc,ltc,tmc,fic,lcc,tdc,eoc,aetherdrift
```

- [ ] Seed SOC (Secrets of Strixhaven Commander)
- [ ] Seed SOS (Secrets of Strixhaven play boosters)
- [ ] Seed BLC (Bloomburrow Commander)
- [ ] Seed FFC (Final Fantasy Commander)
- [ ] Seed remaining EV calculator sets: ltc, tmc, fic, lcc, tdc, eoc, aetherdrift
- [ ] Verify: `GET /v1/sets` returns all seeded sets

---

## Phase 3 — Run first ingest

With the API live and catalog seeded, trigger ingest manually via GitHub Actions
(`workflow_dispatch`) or run containers directly:

```bash
docker run --rm --env-file /etc/market-tracker/env \
  philwin/market-tracker-backend:latest /bin/ingest-prices
```

- [ ] Run `ingest-depth` manually — verify listing depth rows written
- [ ] Run `ingest-prices` manually — verify price snapshots in DB
- [ ] Run `ingest-ebay-scrape` manually — verify eBay sold rows
- [ ] Confirm weekly cron fires on self-hosted runner (check Actions tab after next Sunday)
- [ ] Set `MARKET_TRACKER_API_URL` + `MARKET_TRACKER_API_TOKEN` as repo secrets if ingest POSTs to API

---

## Phase 4 — Deploy frontend

- [ ] Add `.github/workflows/deploy.yml` to `market-tracker-frontend`
  - Build: `npm run build`
  - Deploy to GitHub Pages (or Cloudflare Pages)
  - Set `VITE_API_URL` to `http://192.168.86.199:8080` (or public tunnel URL)
- [ ] Expose API via Cloudflare Tunnel: `market-tracker.futuregadgetlabs.com` → 192.168.86.199:8080
- [ ] Verify frontend loads sets from live API at the public domain

---

## Phase 5 — Migrate V1 historical data (optional, not blocking)

V1 price history lives in `FutureGadgetCollections/collection-market-tracker-data`:
- `data/tcgplayer-price-history.json`
- `data/manapool-latest-prices.json`

Script stub: `market-tracker-backend/scripts/migrate_v1.py`

- [ ] Map V1 card IDs → V2 `display_key` via `card_external_ids` (TCGPlayer product ID)
- [ ] POST to `/v1/admin/cards/snapshots/bulk`
- [ ] Verify snapshot count via `GET /v1/cards/{key}/snapshots`

---

## Phase 6 — Decommission V1

- [ ] Verify card-identifier-backend `MARKET_TRACKER_URL` points at V2 (192.168.86.199:8080)
- [ ] Stop V1 Cloud Run jobs (GCP Console → Cloud Scheduler → disable)
- [ ] Archive V1 repos:
  - `FutureGadgetCollections/collection-market-tracker-backend`
  - `FutureGadgetCollections/collection-market-tracker-data`
  - `FutureGadgetCollections/collection-market-tracker-frontend-admin`
- [ ] Update `infra.json` — market-tracker status `running-on-laptop` → `running`

---

## Phase 7 — Cloud migration (future, when homelab isn't enough)

| Tier | Database | Backend | Frontend |
|---|---|---|---|
| Prod | Neon `main` | Cloud Run `:latest` | GitHub Pages |
| Preprod | Neon branch | Proxmox LXC `:preprod` | Proxmox nginx |
| Demo | Neon branch | Cloud Run (separate service) | Cloudflare Pages |
| Backup | Homelab PG (nightly pg_dump from Neon) | — | — |

- [ ] Create Neon project; migrate schema + data via pg_dump → pg_restore
- [ ] Update `DATABASE_URL` in Cloud Run env to point at Neon
- [ ] Deploy backend to Cloud Run (same Docker image, no code changes)
- [ ] Deploy frontend to GitHub Pages via GitHub Actions
- [ ] Set up nightly pg_dump cron Neon → homelab as DR backup
- [ ] Decommission or repurpose Proxmox LXC 109

---

## Sync workers (BQ + GCS — non-blocking, build when needed)

- [ ] `cmd/sync bigquery` — weekly PG → BQ append
- [ ] `cmd/sync gcs` — weekly JSON bake to GCS bucket
- [ ] Deploy as Cloud Run Jobs + Cloud Scheduler
