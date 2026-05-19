# Slab Cracker — Architecture

## Purpose

A card centering measurement tool that helps collectors decide which graded slabs are worth cracking (re-submitting for a higher grade). The user loads a slab image, draws bounding boxes around the outer slab edge and inner printed art frame, and the tool computes centering percentages and predicts the PSA grade ceiling.

## Repos

| Repo | Role |
|---|---|
| `FG-CollectLabs/slab-cracker-frontend` | Vite/TS workbench — canvas measurement, OCR, session storage |
| `FG-CollectLabs/slab-cracker-extension` | Chrome MV3 extension — CORS-restricted cert scraping, image capture |
| `FG-CollectLabs/slab-cracker-backend` | Go API + Postgres — cert/analysis persistence, trend queries (scaffolded 2026-05-19) |

## Current State (as of 2026-05-19)

No backend exists. All data lives in the browser only:
- **Frontend**: localStorage under `slab-cracker:sessions`, max 12 sessions, each containing: image as data URL (JPEG 92%), user-drawn boxes, cert metadata, centering result.
- **Extension**: `chrome.storage.local` for transient image handoff only — no persistent user data.

## Data Flow

### Standalone frontend
1. User drops/pastes/right-clicks a slab image onto the frontend.
2. Tesseract.js OCR auto-detects cert number from the image ("CERT #XXXXXXXX" for PSA, 10-digit for CGC).
3. If extension is present, frontend sends cert number → extension scrapes PSA/CGC cert page → returns metadata + front/back scan URLs.
4. Extension fetches scans as data URLs (bypasses CORS), hands to frontend via `chrome.storage.local` bridge.
5. User draws two boxes: **card box** (outer slab edge) and **art box** (inner printed frame).
6. Centering computed: `left = art.x1 - card.x1`, `right = card.x2 - art.x2`, `leftPct = left / (left + right) * 100`. Same for vertical.
7. PSA grade ceiling mapped from worst axis: ≤55% → PSA 10, ≤60% → PSA 9, ≤65% → PSA 8, ≤70% → PSA 7, etc.
8. Session saved to localStorage.

### Extension role
- **Context menu**: right-click any image on any site → "Open in Slab Cracker" → fetches image, stashes in `chrome.storage.local`, opens frontend tab with `?capture=<key>`.
- **Cert scraping**: PSA scrapes Next.js RSC payload from `psacard.com/cert/<n>`; CGC scrapes server-rendered HTML from `cgccards.com/certlookup/<n>/`. Both return: grade, card name, front/back scan URLs.
- **CORS bypass**: extension has `host_permissions` for PSA/CGC; frontend requests go through it via `chrome.runtime.sendMessage`.

## Key Source Files

### Frontend (`slab-cracker-frontend/src/`)
| File | Role |
|---|---|
| `main.ts` | Bootstrap, event wiring, state orchestration |
| `canvas.ts` | HTML5 Canvas renderer, box drawing + editing |
| `centering.ts` | Border pixel math, PSA ceiling map |
| `session.ts` | localStorage read/write, session cap (12) |
| `types.ts` | `Session`, `Box`, `CenteringMeasurement`, `CertLookup` types |
| `extension.ts` | Extension ping, cert fetch request, capture handoff |
| `ocr.ts` | Tesseract.js WASM, cert number regex extraction |

### Extension (`slab-cracker-extension/src/`)
| File | Role |
|---|---|
| `background.ts` | Service worker — context menu, region capture, external message handler |
| `psaScrape.ts` | PSA cert page scraper (RSC payload + image gallery) |
| `cgcScrape.ts` | CGC cert page scraper (server-rendered HTML) |
| `content.ts` | Content script on frontend domain — bridges `postMessage` ↔ `chrome.storage.local` |
| `shared.ts` | `stashCapture()` / capture key utils |

## Data Model (current, frontend types)

```typescript
interface Session {
  id: string;
  createdAt: string;          // ISO timestamp
  certLookup?: CertLookup;
  imageDataUrl: string;       // JPEG 92% data URL
  cardBox: Box;               // outer slab edge
  artBox: Box;                // inner printed frame
  measurement: CenteringMeasurement;
}

interface Box { x1: number; y1: number; x2: number; y2: number; }

interface CertLookup {
  company: "psa" | "cgc";
  certNumber: string;
  cardName?: string;
  grade?: string;
  frontImageUrl?: string;
  backImageUrl?: string;
  source: string;
}

interface CenteringMeasurement {
  horizontal: AxisMeasurement;
  vertical: AxisMeasurement;
  summary: string;
  psaCeiling: string;         // e.g. "PSA 9"
}

interface AxisMeasurement {
  leftPx: number; rightPx: number;
  leftPct: number; rightPct: number;
  ratioStr: string;           // e.g. "52/48"
  delta: number;              // distance from perfect center
}
```

## Backend Schema (live as of 2026-05-19, migration `0001_init.sql`)

```sql
-- one row per unique cert
CREATE TABLE certs (
  cert_number   TEXT PRIMARY KEY,
  company       TEXT NOT NULL CHECK (company IN ('psa','cgc')),
  card_name     TEXT,
  grade         TEXT,
  set_name      TEXT,
  year          TEXT,
  display_key   TEXT,                   -- nullable link to market-tracker cards.display_key
  fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- front/back scan URLs per cert
CREATE TABLE cert_scans (
  cert_number   TEXT PRIMARY KEY REFERENCES certs ON DELETE CASCADE,
  front_url     TEXT,
  back_url      TEXT,
  fetched_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- centering analyses — multiple per cert allowed; supports regrading history
CREATE TABLE centering_analyses (
  id            BIGSERIAL PRIMARY KEY,
  cert_number   TEXT NOT NULL REFERENCES certs ON DELETE CASCADE,
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
```

**No `card_catalog` table.** Card identity is delegated to `market-tracker-backend.cards.display_key` — see DECISIONS.md D-004.

## API Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/v1/certs/{cert_number}` | public | cert + scans + full analysis history |
| `POST` | `/v1/certs/{cert_number}` | Bearer | upsert cert metadata + scans (extension) |
| `POST` | `/v1/certs/{cert_number}/analyses` | Bearer | save a centering analysis |
| `GET` | `/v1/cards/{display_key}/analyses` | public | trend view — all analyses for one card |
| `GET` | `/healthz` `/readyz` | public | liveness / readiness |

## Market Tracker Integration

The crack-recommendation signal joins data from two backends on `display_key`:

| Source | Data |
|---|---|
| slab-cracker-backend `/v1/certs/{cert_number}` | PSA ceiling from centering measurement |
| market-tracker-backend `/v1/cards/{display_key}/graded` | PSA9 / PSA10 / CGC10 prices, gem rates |

Frontend logic: "worth cracking" = `ceiling > current_grade AND (psa10 - psa9) > $25`.

## Glossary

| Term | Meaning |
|---|---|
| **Slab** | A graded card sealed in a plastic holder by PSA, CGC, etc. |
| **Cert / Cert number** | The unique ID printed on the slab label |
| **Card box** | User-drawn bounding box around the outer slab edge |
| **Art box** | User-drawn bounding box around the inner printed frame |
| **PSA ceiling** | The highest PSA grade the measured centering could achieve — not the final grade (surface/corners not measured) |
| **Crack** | Removing a card from its slab to re-submit for a (hopefully) higher grade |
