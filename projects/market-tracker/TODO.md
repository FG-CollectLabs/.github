# Market Tracker V2 — TODO

Goal: V2 live on Proxmox, data flowing from sellthrough-analyzer, V1 decommissioned.

---

## Phase 1 — Deploy backend to Proxmox (TODAY)

### Already done
- [x] DB `market_tracker` created on 192.168.86.182
- [x] Migrations 0001–0005 applied
- [x] `fg_app` granted schema permissions
- [x] `Dockerfile` written
- [x] GitHub Actions CI written (`.github/workflows/docker.yml`)
- [x] `deploy.sh` written (targets 192.168.86.199 by default)
- [x] `deploy/env.production.example` written
- [x] `scripts/gen_prod_env.ps1` written — generates /etc/market-tracker/env from local secrets
- [x] GitHub repo created at https://github.com/FG-CollectLabs/market-tracker-backend
- [x] `philwin/market-tracker-backend:latest` built and pushed to Docker Hub

### Already done
- [x] GitHub repo created: https://github.com/FG-CollectLabs/market-tracker-backend
- [x] Dockerfile, CI workflow, deploy.sh committed and pushed
- [x] DOCKERHUB_TOKEN repo secret set → CI building `philwin/market-tracker-backend:latest`
- [x] `infra.json` updated with proposed LXC details (id=109, ip=192.168.86.199, name=fg-market-app)

### Still needed

- [ ] **Provision LXC on Proxmox** for market-tracker-backend
  - LXC 109 on proxmox1, IP 192.168.86.199, name `fg-market-app`
  - 1 CPU, 512MB RAM, 4GB disk — same spec as fg-card-app
  - Install Docker inside it: `apt install -y docker.io`
  - Append SSH key to `/root/.ssh/authorized_keys` inside the LXC

- [ ] **Create env file on LXC**
  ```bash
  mkdir -p /etc/market-tracker
  # Copy deploy/env.production.example → /etc/market-tracker/env
  # Fill in: DATABASE_URL (real password from pg-servers.json), ADMIN_API_TOKEN (openssl rand -hex 32)
  ```

- [ ] **Run deploy**: `cd market-tracker-backend && ./deploy.sh`

- [ ] **Verify**: `curl http://192.168.86.199:8080/healthz` → `ok`
                   `curl http://192.168.86.199:8080/readyz` → `ready`

---

## Phase 2 — Seed catalog (SOC + SOS + Bloomburrow + Final Fantasy)

The V1 `collection-market-tracker-data` repo has `add_soc_cards.py` and
`single-cards.json` / `sealed-products.json` as a reference for the catalog shape.
V2 ingest is via `POST /v1/admin/cards` + `/v1/admin/cards/external-ids`.

- [ ] **Seed catalog via `cmd/seed`** (uses Scryfall — no script needed)
  ```bash
  DATABASE_URL="postgres://fg_app:<password>@192.168.86.182:5432/market_tracker?sslmode=disable" \
    go run ./cmd/seed --sets blc,ffc,soc,sos
  ```
  Or exec into the running container: `docker exec market-tracker-backend /bin/seed --sets blc,ffc,soc,sos`
- [ ] Run seed for SOC (Secrets of Strixhaven Commander)
- [ ] Run seed for SOS (Secrets of Strixhaven play boosters)
- [ ] Run seed for BLC (Bloomburrow Commander)
- [ ] Run seed for FFC (Final Fantasy Commander)
- [ ] Verify via `GET /v1/sets` that all four sets appear

---

## Phase 3 — Wire sellthrough-analyzer → V2 backend

The `BackendAPIClient` in `sellthrough-analyzer/src/sellthrough/storage/backend_api.py`
is already written. The blockers are the source adapters.

- [ ] **Implement TCGPlayer adapter** (`sources/tcgplayer.py`)
  - Weekly price snapshot per card: market price, median, lowest, listed quantity
  - Output: list of `CardSnapshotRow` objects
- [ ] **Implement ManaPool adapter** (`sources/manapool.py` — new file)
  - Lowest asking price per card
- [ ] **Implement eBay adapter** (`sources/ebay.py`)
  - Sold-listing median + sample size (scrape or Finding API)
- [ ] **Wire CLI command** `sellthrough ingest` in `cli.py`
  - Read product list from `catalog/products.py`
  - Fan out to adapters
  - POST to backend via `BackendAPIClient`
- [ ] **Run first ingest manually** against the running Proxmox backend
- [ ] **Schedule weekly GitHub Actions cron** (`.github/workflows/ingest.yml` — scaffold exists,
      needs `MARKET_TRACKER_API_URL` + `MARKET_TRACKER_API_TOKEN` repo secrets)

---

## Phase 4 — Migrate V1 historical data

V1 price history lives in:
- `collection-market-tracker-data/data/tcgplayer-price-history.json` — TCGPlayer weekly history
- `collection-market-tracker-data/data/manapool-latest-prices.json` — ManaPool latest
- V1 BigQuery tables (if we want full history beyond what's in the JSON files)

Script: `market-tracker-backend/scripts/migrate_v1.py`

- [ ] Inspect V1 JSON format: `single-cards.json`, `tcgplayer-price-history.json`
- [ ] Map V1 card IDs → V2 `display_key` (via TCGPlayer product ID in `card_external_ids`)
- [ ] Run migration: reads V1 JSON → POST to `/v1/admin/cards/snapshots/bulk`
- [ ] Verify snapshot count via `GET /v1/cards/{key}/snapshots`

---

## Phase 5 — Decommission V1

- [ ] **Stop V1 Cloud Run jobs** (sync-prices + sync-feeds)
  - GCP Console → Cloud Scheduler → disable both triggers
  - Cloud Run → delete or set min-instances=0
- [ ] **Verify card-identifier-backend still works** — it calls market-tracker at
      `http://192.168.86.182:8080` (old address); update its `MARKET_TRACKER_URL`
      to point at V2 once V2 is live: `http://192.168.86.199:8080`
- [ ] **Archive V1 repos** in GitHub (Settings → Archive) after confirming V2 has all data:
  - `FutureGadgetCollections/collection-market-tracker-backend`
  - `FutureGadgetCollections/collection-market-tracker-data`
  - `FutureGadgetCollections/collection-market-tracker-frontend-admin`
- [ ] **Update infra.json** — change market-tracker status from `running-on-laptop` to `running`

---

## Phase 6 — Frontend (not blocking V1 decommission)

- [ ] Stand up Hugo frontend (`market-tracker-frontend` repo — not yet created)
- [ ] Wire Google sign-in for admin writes
- [ ] Public read view: set browser, card price history charts
- [ ] Deploy via Cloudflare Tunnel or reverse proxy for `market-tracker.futuregadgetlabs.com`

---

## Sync workers (BQ + GCS — not blocking)

- [ ] Implement `cmd/sync bigquery` — weekly PG → BQ append
- [ ] Implement `cmd/sync gcs` — weekly JSON bake to GCS bucket
- [ ] Deploy as Cloud Run Jobs + Cloud Scheduler
- [ ] Network path: Cloud Run → Tailscale/tunnel → home-lab PG (method TBD)

---

## Phase 7 — Cloud migration + multi-tier deployment (future)

Target architecture once ready to move off home lab:

| Tier | Database | Backend | Frontend |
|---|---|---|---|
| Prod | Neon `main` branch | Cloud Run | GitHub Pages (`main`) |
| Preprod | Neon branch (instant, no sync needed) | Proxmox LXC | Proxmox nginx |
| Demo | Neon branch | Cloud Run (separate service) | Cloudflare Pages preview |
| Home lab PG | Nightly `pg_dump` from Neon — DR backup only | — | — |

### Steps
- [ ] Create Neon project, migrate data: `pg_dump` from 192.168.86.182 → `pg_restore` to Neon
- [ ] Update `DATABASE_URL` in Cloud Run env → point at Neon
- [ ] Deploy backend to Cloud Run: same Docker image from Docker Hub, no code changes
- [ ] Set up Cloud Run staging service (preprod) pointing at a Neon branch
- [ ] Deploy Hugo frontend to GitHub Pages via GitHub Actions (`main` branch only)
- [ ] Set up nightly `pg_dump` cron from Neon → home lab as DR backup
- [ ] Update Cloudflare tunnel hostnames to point at Cloud Run URLs
- [ ] Decommission Proxmox market-tracker LXC (or repurpose for preprod)
