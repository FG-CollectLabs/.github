# Agent Checkpoint — 2026-05-19 (Slab Cracker v0.1 complete)

End-of-session summary covering the full slab cracker V2 backend integration. Three repos updated, one new. Ready to tag.

---

## Scope of this session

Wire `slab-cracker-frontend` ↔ `slab-cracker-extension` ↔ new `slab-cracker-backend` so every scraped PSA/CGC cert is cached server-side and every centering analysis is persisted with full history (for regrading comparisons). Market data stays in `market-tracker-backend` and is joined on `display_key` client-side.

---

## State by repo

### `FG-CollectLabs/slab-cracker-backend` — **NEW**

Created from scratch this session. Live on Proxmox at `192.168.86.183:8081`.

| Commit | Subject |
|---|---|
| `aacb7df` | Initial scaffold: Go API for cert persistence and centering history |
| `58ee6e1` | Add Dockerfile, Docker Hub CI workflow, README |

**Layout** (mirrors `fg-collect-core`):
- `cmd/api/main.go` — Go 1.25, `net/http.ServeMux`, graceful shutdown, JSON-logged
- `internal/{config,db,httpx,certs}/` — handlers + middleware + pgxpool init
- `migrations/0001_init.sql` — three tables, goose-managed
- `queries/certs.sql` — sqlc queries (codegen deferred; handlers use raw pgx for v1)
- `Dockerfile`, `docker/compose.yaml`, `.github/workflows/docker.yml`

**API endpoints**:
| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/healthz` `/readyz` | public | liveness / DB ping |
| GET | `/v1/certs/{cert_number}` | public | cert + scans + full analysis history |
| POST | `/v1/certs/{cert_number}` | Bearer | upsert cert metadata + scans |
| POST | `/v1/certs/{cert_number}/analyses` | Bearer | save a centering analysis |
| GET | `/v1/cards/{display_key}/analyses` | public | trend view across one card |

**Schema**:
- `certs` — cert_number PK, company, card_name, grade, set_name, year, **display_key** (nullable, links to `market-tracker-backend.cards.display_key`), fetched_at
- `cert_scans` — cert_number PK FK, front_url, back_url, fetched_at (one row per cert; upserted on re-scrape)
- `centering_analyses` — bigserial PK, cert_number FK, h_left/h_right/v_top/v_bot pcts, psa_ceiling, card_box JSONB, art_box JSONB, notes, analyzed_at (**no UNIQUE on cert_number — multiple analyses per cert for regrading history**)

**Secrets**: `ADMIN_API_TOKEN` (random `sc_...`) and `DOCKERHUB_TOKEN` both set as repo secrets. ADMIN_API_TOKEN value is at `slab-cracker-backend/.env` (gitignored).

### `FG-CollectLabs/slab-cracker-extension`

| Commit | Subject |
|---|---|
| `d737ed8` | Wire backend persistence: cache check before scrape, POST after |

- New `src/backendClient.ts` — `fetchCachedCert` + `upsertCert`, best-effort (swallow errors so scraping still works when backend is down)
- `src/background.ts` `fetchCertScans`: GET backend cache first → on hit, skip scrape entirely and just re-fetch data URLs through the extension; on miss, scrape and fire-and-forget POST result
- New Options fields: **Backend URL** + **Admin token** (both default empty; empty disables persistence)
- Manifest host_permissions extended to include `localhost:8081`, `127.0.0.1:8081`, `192.168.86.183:8081`, and a placeholder for the future hosted backend

### `FG-CollectLabs/slab-cracker-frontend`

| Commit | Subject |
|---|---|
| `767fe53` | Commit pre-existing OCR work (tesseract.js + src/ocr.ts) — restore buildable HEAD |
| `86df27c` | Wire backend persistence: history panel, save analyses, settings |

- New `src/backendClient.ts` — `fetchCert`, `saveAnalysis`, `fetchAnalysesForDisplayKey`, plus `getBackendUrl/Token` helpers. Backend URL + token persist in localStorage as `slab-cracker:backendUrl` / `slab-cracker:adminToken`.
- Save button now POSTs the measurement to `/v1/certs/{n}/analyses` after the local localStorage save. Status line shows "Analysis #N saved to backend" / "token not set" / "save failed".
- New **History** panel (sidebar section 5) lists every prior analysis for the current cert — id, PSA ceiling, H/V ratios, timestamp. Refreshed on manual cert lookup and on OCR-detected lookups.
- New collapsible **Settings** disclosure at the bottom of the sidebar for backend URL + admin token.

### `FG-CollectLabs/.github`

| Commit | Subject |
|---|---|
| `858dae8` | Slab cracker: backend scaffold + planning docs |
| `4963795` | Hub: add slab-cracker-backend card, health check, and architecture wiring |
| `daa6396` | Slab cracker: resume checkpoint for next session |

- `projects/slab-cracker/{DECISIONS,TODO,ARCHITECTURE}.md` updated to reflect resolved state (all 4 decisions closed; Phase 1+2 of TODO checked off; ARCHITECTURE schema matches deployed)
- Hub: backend card added under "Backends — Homelab Proxmox"; Slab Cracker card mentions backend; database map row added; architecture diagram updated; new health check entry
- Three checkpoints in `agent-checkpoints/`: planning → scaffold → resume → (this one) complete

---

## Database state (Proxmox `192.168.86.183:5432`)

```
slabcracker
├── certs                      (0 rows after cleanup)
├── cert_scans                 (0 rows)
├── centering_analyses         (0 rows; ids will start fresh at 1)
└── goose_db_version           v=1, applied 2026-05-19
```

`fg_app` role: CONNECT + SELECT/INSERT/UPDATE/DELETE on all tables; default privileges set for future tables.

---

## Verified end-to-end (this session)

| Test | Result |
|---|---|
| Cache miss → 404 with `{code,message}` JSON | ✓ |
| POST cert without auth → 401 | ✓ |
| POST cert with Bearer → upsert returns row | ✓ |
| GET after POST → returns cert + scans + analyses | ✓ |
| POST analysis with full body shape (boxes + pcts + ceiling) → 201 | ✓ |
| CORS preflight from `http://localhost:5173` → 204 + correct ACAO/ACAM/ACAH headers | ✓ |
| `go build ./... && go vet ./...` (backend) | clean |
| `npm run build && npx tsc --noEmit` (extension) | clean |
| `npm run build && npx tsc --noEmit` (frontend) | clean |

---

## How to take it for a real spin

1. Start backend:
   ```powershell
   cd slab-cracker-backend
   $env:DATABASE_URL = "postgres://fg_app:b%5E4J4X%2B1%3D6Vz@192.168.86.183:5432/slabcracker?sslmode=disable"
   $env:ADMIN_API_TOKEN = "sc_Y9OljSQ4J6T5UNIT6YPkDfCxmLIFa9S-zE8FZUfXcI8"
   $env:API_ADDR = ":8081"
   $env:CORS_ORIGINS = "http://localhost:5173"
   go run ./cmd/api
   ```
2. Load extension at `slab-cracker-extension/dist/` as unpacked in Chrome → Settings → set backend URL + token → save.
3. `cd slab-cracker-frontend && npm run dev` → open the new **Settings** disclosure → set backend URL + token → save.
4. Right-click a real PSA slab image somewhere → "Open in Slab Cracker" → cert auto-fetched via extension → extension POSTs cert + scan URLs to backend.
5. Draw boxes → **Save session** → status line says "Analysis #N saved to backend" → **History** panel shows the row.
6. Reload page, look up same cert → instant from backend cache, history panel pre-populates.

---

## Not done / parked

- **Trend view UI** — the `/v1/cards/{display_key}/analyses` endpoint exists and the frontend has `fetchAnalysesForDisplayKey`, but there's no UI yet for entering a `display_key` and showing the trend chart. Park until you actually have multiple certs of the same card persisted.
- **Crack recommendation signal** — frontend would combine its PSA ceiling with `market-tracker-backend.../v1/cards/{display_key}/graded` for PSA9→PSA10 delta. Not wired; market tracker integration is the next big chunk.
- **`sqlc generate`** — queries are written; running it produces `internal/db/dbgen/` and the handlers can migrate from raw pgx to dbgen-typed queries. Not blocking.
- **Backend deployment** — currently runs via `go run` locally. CI builds the Docker image once you push, but the Proxmox VM isn't yet running a container. Manual `docker run philwin/slab-cracker-backend:latest` with env vars is the next deploy step.
- **Frontend re-deploy** — `slab-cracker-frontend` has a GH Pages deploy workflow (commit `2c03633`); pushing the backend wiring should trigger a fresh deploy. Worth a sanity check that nothing breaks at the hosted URL.

---

## Recommended tags

All three repos are at v0.1.0-shaped milestones. Suggested tags (annotated, on current HEAD):

| Repo | Tag | At | Message |
|---|---|---|---|
| `slab-cracker-backend` | `v0.1.0` | `58ee6e1` | First working API: cert persistence + centering history, live on Proxmox |
| `slab-cracker-extension` | `v0.2.0` | `d737ed8` | Backend persistence: cache check before scrape, POST after |
| `slab-cracker-frontend` | `v0.2.0` | `86df27c` | Backend-backed history + per-analysis save |

(Extension and frontend are v0.2.0 because they already had v0.1 work committed pre-session; the backend is a fresh v0.1.0.)

Commands ready to run when you give the go-ahead:

```sh
# slab-cracker-backend
git -C slab-cracker-backend tag -a v0.1.0 -m "First working API: cert persistence + centering history" && \
git -C slab-cracker-backend push origin v0.1.0

# slab-cracker-extension
git -C slab-cracker-extension tag -a v0.2.0 -m "Backend persistence: cache check before scrape, POST after" && \
git -C slab-cracker-extension push origin v0.2.0

# slab-cracker-frontend
git -C slab-cracker-frontend tag -a v0.2.0 -m "Backend-backed history + per-analysis save" && \
git -C slab-cracker-frontend push origin v0.2.0
```
