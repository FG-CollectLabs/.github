# Agent Checkpoint — 2026-05-19

## Session
Slab Cracker backend scaffold (picks up from `2026-05-19-slab-cracker-backend-planning.md`)

---

## Decisions confirmed this session

| # | Decision | Resolution |
|---|---|---|
| D-001 | Go + pgx/sqlc for backend | Confirmed |
| D-002 | Extension scrapes + POSTs (human solves captcha) | Confirmed — no full automation; extension makes it seamless |
| D-003 | Store all analyses per cert | Confirmed — needed for regrading history (regrade → same grade → decide to resubmit or give up) |
| D-004 | Card catalog normalization | **Changed**: dropped `card_catalog` table entirely. Use `display_key TEXT` (nullable) on `certs` as a FK-by-convention link to `market-tracker-backend.cards.display_key`. Frontend calls both APIs independently and merges. |

**Market tracker integration rationale**: market tracker already has `graded_snapshots_weekly` with PSA9/PSA10/CGC10 prices + gem rates + ROI math. The slab cracker frontend will call market tracker's `/v1/cards/{display_key}/graded` to get price delta for the crack recommendation signal. No cross-DB queries; `display_key` is the join key.

---

## What was built

`FG-CollectLabs/slab-cracker-backend` scaffolded at `c:\Users\nguye\VSCode\FG-CollectLabs\slab-cracker-backend`

```
slab-cracker-backend/
├── cmd/api/main.go                    Go 1.25, net/http.ServeMux, graceful shutdown
├── internal/
│   ├── config/config.go               DATABASE_URL, API_ADDR, CORS_ORIGINS, ADMIN_API_TOKEN
│   ├── db/db.go                       pgxpool.Open with Ping
│   ├── httpx/httpx.go                 Chain, BearerAuth, CORS, Recover, Logging, WriteJSON/WriteError
│   └── certs/handler.go               All 4 endpoints (raw pgx, no sqlc generate needed yet)
├── migrations/0001_init.sql           certs, cert_scans, centering_analyses (goose Up/Down)
├── queries/certs.sql                  sqlc queries (run `sqlc generate` to produce dbgen/)
├── docker/compose.yaml                local postgres on port 5434
├── go.mod                             github.com/FG-CollectLabs/slab-cracker-backend, pgx/v5
├── sqlc.yaml
└── .env.example
```

---

## Schema

```sql
CREATE TABLE certs (
    cert_number  TEXT PRIMARY KEY,
    company      TEXT NOT NULL CHECK (company IN ('psa', 'cgc')),
    card_name    TEXT,
    grade        TEXT,
    set_name     TEXT,
    year         TEXT,
    display_key  TEXT,   -- link to market-tracker cards.display_key
    fetched_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cert_scans (
    cert_number  TEXT PRIMARY KEY REFERENCES certs ON DELETE CASCADE,
    front_url    TEXT,
    back_url     TEXT,
    fetched_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE centering_analyses (
    id           BIGSERIAL PRIMARY KEY,
    cert_number  TEXT NOT NULL REFERENCES certs ON DELETE CASCADE,
    h_left_pct   NUMERIC(5,2),
    h_right_pct  NUMERIC(5,2),
    v_top_pct    NUMERIC(5,2),
    v_bot_pct    NUMERIC(5,2),
    psa_ceiling  TEXT,
    card_box     JSONB,
    art_box      JSONB,
    notes        TEXT,
    analyzed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## API endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/v1/certs/{cert_number}` | Public | Cert + scans + full analysis history |
| `POST` | `/v1/certs/{cert_number}` | Bearer | Upsert cert metadata + scans |
| `POST` | `/v1/certs/{cert_number}/analyses` | Bearer | Save a centering analysis |
| `GET` | `/v1/cards/{display_key}/analyses` | Public | Trend view — all analyses for a card |
| `GET` | `/healthz` | Public | Liveness |
| `GET` | `/readyz` | Public | DB ping |

---

## What to do next

1. **Stand up Postgres on Proxmox** — create `slabcracker` database on VM at `192.168.86.183:5432`
   ```sql
   CREATE DATABASE slabcracker;
   CREATE USER fg_app WITH PASSWORD '...';
   GRANT ALL ON DATABASE slabcracker TO fg_app;
   ```
2. **Apply migration** — install goose, run `goose -dir migrations postgres "$DATABASE_URL" up`
3. **`go mod tidy`** — generates `go.sum`
4. **Build + test** — `go build ./...`, `go vet ./...`
5. **Wire extension** — `POST /v1/certs/{certNum}` after PSA/CGC scrape; check `GET` first to skip re-scrape if cached
6. **Wire frontend** — check backend on cert load; `POST` analysis on session save; "History" panel; "Trend" view via `/v1/cards/{display_key}/analyses`
7. **Crack signal** — frontend combines PSA ceiling (slab cracker) + PSA9→PSA10 delta (market tracker `/v1/cards/{display_key}/graded`) to surface "worth cracking"
8. **(Later)** Run `sqlc generate` and migrate handlers from raw pgx to dbgen types

---

## Relevant paths

| Path | What's there |
|---|---|
| `slab-cracker-backend/cmd/api/main.go` | Entry point |
| `slab-cracker-backend/internal/certs/handler.go` | All 4 endpoints |
| `slab-cracker-backend/migrations/0001_init.sql` | Schema |
| `slab-cracker-backend/queries/certs.sql` | sqlc queries |
| `slab-cracker-backend/.env.example` | Env var reference |
| `market-tracker-backend/internal/graded/handler.go` | PSA9/PSA10 price endpoint for crack signal |
| `slab-cracker-frontend/src/extension.ts` | Extension ping — needs backend URL added |
| `slab-cracker-extension/src/background.ts` | Service worker — add POST after scrape |
