# Agent Checkpoint — 2026-05-19

## What we worked on

Architecture survey of Slab Cracker V2 (frontend + extension) and planning for a Go backend + Postgres persistence layer.

---

## Current state of the tool

### Two repos, no backend

| Repo | Role |
|---|---|
| `FG-CollectLabs/slab-cracker-frontend` | Vite/TS workbench — canvas measurement, OCR, session storage |
| `FG-CollectLabs/slab-cracker-extension` | Chrome MV3 — CORS-restricted cert scraping, image capture from other sites |

**All data is in the browser only.** localStorage under `slab-cracker:sessions`, capped at 12 sessions, each containing the image as a JPEG data URL, user-drawn boxes, cert metadata, and centering result.

### What the extension actually does

The extension exists to solve two things the frontend can't:
1. **CORS bypass** — PSA (`psacard.com`) and CGC (`cgccards.com`) block cross-origin requests. The extension has `host_permissions` and scrapes the cert page directly, returning grade, card name, and front/back scan URLs.
2. **Image capture** — right-click any image on any website → "Open in Slab Cracker" → extension fetches as data URL, stashes in `chrome.storage.local` with a key, opens frontend with `?capture=<key>`. Content script bridges the storage handoff to the frontend page.

### How centering is computed

1. User draws two boxes on the canvas:
   - **Card box** — outer slab edge
   - **Art box** — inner printed frame
2. Border pixels: `left = art.x1 - card.x1`, `right = card.x2 - art.x2`, same for vertical.
3. Percentages: `leftPct = left / (left + right) * 100`.
4. PSA grade ceiling mapped from worst axis: ≤55% → PSA 10, ≤60% → PSA 9, ≤65% → PSA 8, ≤70% → PSA 7, etc.
5. This is a **ceiling**, not a final grade — surface, corners, edges not measured.

### OCR
Tesseract.js (WASM) auto-extracts cert number on image load. PSA pattern: `CERT #XXXXXXXX`; CGC: 10-digit number; PSA fallback: 8-digit.

---

## Pain points identified (user)

1. **Repeat analysis** — no dedup; same cert gets re-measured from scratch every time.
2. **No trend view** — can't look at centering distributions across many certs of the same card.
3. **No crack decision support** — no signal for "this PSA 9 has centering that projects PSA 10, worth cracking."

---

## Agreed direction

Build a **Go backend + Postgres** following the `fg-collect-core` pattern (same as market-tracker-backend, card-inventory-backend, card-identifier-backend).

**Key architecture decision**: Extension continues to scrape PSA/CGC. Backend is a persistence + query layer only — no need to re-implement scraping in Go. Extension POSTs cert metadata after scraping; backend stores and serves it.

---

## Planned backend schema

```sql
-- one row per unique cert
CREATE TABLE certs (
  cert_number   TEXT PRIMARY KEY,
  company       TEXT NOT NULL,          -- 'psa' | 'cgc'
  card_name     TEXT,
  grade         TEXT,
  set_name      TEXT,
  year          TEXT,
  fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- front/back scan URLs per cert
CREATE TABLE cert_scans (
  cert_number   TEXT PRIMARY KEY REFERENCES certs,
  front_url     TEXT,
  back_url      TEXT,
  fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- centering analyses — multiple per cert allowed (store all, show history)
CREATE TABLE centering_analyses (
  id            BIGSERIAL PRIMARY KEY,
  cert_number   TEXT NOT NULL REFERENCES certs,
  h_left_pct    NUMERIC(5,2),
  h_right_pct   NUMERIC(5,2),
  v_top_pct     NUMERIC(5,2),
  v_bot_pct     NUMERIC(5,2),
  psa_ceiling   TEXT,
  card_box      JSONB,                  -- {x1,y1,x2,y2}
  art_box       JSONB,
  notes         TEXT,
  analyzed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- normalized card identity for grouping many certs of the same card
CREATE TABLE card_catalog (
  id               BIGSERIAL PRIMARY KEY,
  game             TEXT NOT NULL,       -- 'pokemon' | 'mtg' | etc.
  set_code         TEXT,
  collector_number TEXT,
  card_name        TEXT,
  UNIQUE (game, set_code, collector_number)
);

-- link cert → canonical card (populate lazily — don't block v1 on perfect normalization)
ALTER TABLE certs ADD COLUMN card_catalog_id BIGINT REFERENCES card_catalog;
```

---

## Planned API endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/certs/:certNumber` | Return cert + scans + all analyses; 404 if not cached |
| `POST` | `/certs/:certNumber` | Upsert cert metadata + scans (called by extension post-scrape) |
| `POST` | `/certs/:certNumber/analyses` | Save a new centering analysis session |
| `GET` | `/cards/:cardCatalogId/analyses` | All analyses for a card — trend view |

---

## Implementation order

1. Scaffold `slab-cracker-backend` repo — Go module, cmd/api, internal/, same layout as fg-collect-core
2. Stand up Postgres DB on Proxmox homelab, add to `C:\Users\nguye\.config\fg-collectlabs\pg-servers.json`
3. Schema migration — all four tables above
4. sqlc queries — upsert cert, upsert cert_scans, insert analysis, fetch by cert, fetch by card
5. API endpoints — GET + POST /certs/:certNumber, POST analyses, GET trend
6. Extension — POST cert data to backend after scrape; check backend before re-scraping
7. Frontend — check backend on cert load; POST analysis on session save; "History" panel; "Trend" view
8. Crack recommendation signal — if grade < PSA ceiling, surface "worth cracking"

---

## Open decisions (need Phil sign-off before proceeding)

| # | Question | Leaning |
|---|---|---|
| D-001 | Go + pgx/sqlc confirmed for backend? | Yes — matches all other FG backends |
| D-002 | Extension scrapes, POSTs to backend (vs backend scraping itself)? | Option A: extension scrapes |
| D-003 | Store all analyses per cert, not just latest? | Yes — enables history + spotting user error |
| D-004 | Card catalog normalization: raw card_name to start, FK populated lazily? | Yes — don't block v1 |

---

## What to do next

1. Phil signs off on the four open decisions above.
2. Create `FG-CollectLabs/slab-cracker-backend` repo.
3. Scaffold Go module following `FG-CollectShop/fg-collect-core` pattern.
4. Stand up Postgres on Proxmox and write the schema migration.

---

## Relevant paths

| Path | What's there |
|---|---|
| `slab-cracker-frontend/src/main.ts` | Bootstrap + state orchestration |
| `slab-cracker-frontend/src/canvas.ts` | HTML5 Canvas, box drawing |
| `slab-cracker-frontend/src/centering.ts` | Border pixel math, PSA ceiling map |
| `slab-cracker-frontend/src/session.ts` | localStorage read/write (12-session cap) |
| `slab-cracker-frontend/src/types.ts` | `Session`, `Box`, `CenteringMeasurement`, `CertLookup` |
| `slab-cracker-frontend/src/extension.ts` | Extension ping + cert fetch request |
| `slab-cracker-frontend/src/ocr.ts` | Tesseract.js OCR, cert number regex |
| `slab-cracker-extension/src/background.ts` | Service worker — context menu, capture, external messages |
| `slab-cracker-extension/src/psaScrape.ts` | PSA cert page scraper |
| `slab-cracker-extension/src/cgcScrape.ts` | CGC cert page scraper |
| `slab-cracker-extension/src/content.ts` | Frontend-domain bridge for storage handoff |
