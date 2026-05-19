# Agent Checkpoint — 2026-05-19 (resume next session)

## Where we left off

Slab Cracker V2 backend is **live and verified** on Proxmox. GitHub repo created and pushed. Hub updated. The next session should pick up at **extension + frontend wiring**.

---

## State of the world

### Repos
| Repo | State |
|---|---|
| `FG-CollectLabs/slab-cracker-backend` | Created (public), pushed to `main`. Initial commit `aacb7df` (scaffold) + `58ee6e1` (Dockerfile, CI, README). |
| `FG-CollectLabs/.github` | Hub updated (`4963795`) — backend card, health check, db map, architecture diagram. Pushed. |
| `FG-CollectLabs/slab-cracker-extension` | **Untouched** — needs work (see "next session" below). |
| `FG-CollectLabs/slab-cracker-frontend` | **Untouched** — needs work. |

### Infrastructure
- DB on Proxmox: `slabcracker` database on `192.168.86.183:5432`. Tables: `certs`, `cert_scans`, `centering_analyses`, `goose_db_version`. `fg_app` role has DML + default privileges.
- API: builds clean, all 4 v1 endpoints + healthz/readyz verified with full POST/GET roundtrip.
- Local `.env` at `slab-cracker-backend/.env` (gitignored) has working `DATABASE_URL` + `ADMIN_API_TOKEN`.

### Secrets / tokens
- `ADMIN_API_TOKEN` = `sc_Y9OljSQ4J6T5UNIT6YPkDfCxmLIFa9S-zE8FZUfXcI8` (in `.env`, also set as repo secret on slab-cracker-backend).
- ⚠️ **Action item for Phil**: copy `DOCKERHUB_TOKEN` from market-tracker-backend repo secrets into slab-cracker-backend repo secrets so the Docker Hub CI workflow can run. (GitHub API can't read secret values, so I couldn't auto-copy.)

### Workspace
- `FG-CollectLabs.code-workspace` already includes the new `slab-cracker-backend` folder.

---

## What to do next (in order)

### 1. Extension wiring (`slab-cracker-extension`)

Goal: extension POSTs scraped cert data to the backend, and checks the backend first before re-scraping.

- **Options page** — add 2 fields: `backendUrl` (default `http://localhost:8081`) and `adminToken` (the Bearer token). Store in `chrome.storage.sync`.
- **`background.ts`** — after a successful PSA/CGC scrape returns, POST to `${backendUrl}/v1/certs/{cert_number}` with `Authorization: Bearer ${adminToken}`. Body: `{ company, card_name, grade, set_name, year, front_url, back_url }`.
- **Cache check** — before scraping, GET `${backendUrl}/v1/certs/{cert_number}`. If 200, return cached cert metadata to the frontend without re-scraping. If 404, scrape as usual.
- **`display_key`** — not set by the extension. Leave it null on POST; the frontend can patch it later when the user links a card.

Relevant files: `slab-cracker-extension/src/background.ts`, `src/psaScrape.ts`, `src/cgcScrape.ts`, `src/options.ts`, `src/shared.ts`.

### 2. Frontend wiring (`slab-cracker-frontend`)

Goal: persist every centering analysis to the backend; show history + trend; surface crack recommendation.

- **Settings UI** — add `backendUrl` + `adminToken` to the existing options panel (or a new gear icon).
- **On image load + cert detected** — GET `${backendUrl}/v1/certs/{cert_number}`. If found, hydrate UI with prior analyses (history panel).
- **On session save** — POST to `${backendUrl}/v1/certs/{cert_number}/analyses` with body `{ h_left_pct, h_right_pct, v_top_pct, v_bot_pct, psa_ceiling, card_box, art_box, notes }`.
- **History panel** — list all analyses for this cert, newest first. Show measurement summary + analyzed_at. Useful when comparing pre/post-regrade.
- **Trend view** — when user enters a `display_key`, GET `${backendUrl}/v1/cards/{display_key}/analyses` and chart centering distributions across certs.
- **Crack signal** — separate fetch: GET `${marketTrackerUrl}/v1/cards/{display_key}/graded` for PSA9/PSA10/CGC10 prices and gem rates. Combine with slab cracker's PSA ceiling. Surface "worth cracking" badge when `ceiling > current_grade AND (psa10 - psa9) > $25`.

Relevant files: `slab-cracker-frontend/src/main.ts`, `src/session.ts`, `src/types.ts`, `src/extension.ts`.

### 3. Deploy backend to homelab (optional, after extension+frontend work locally)

Pattern matches `market-tracker-backend`:
- `docker pull philwin/slab-cracker-backend:latest` on the Proxmox VM (CI publishes this once DOCKERHUB_TOKEN is set).
- Provision env vars: `DATABASE_URL`, `ADMIN_API_TOKEN`, `CORS_ORIGINS`.
- Expose `:8081`. No Cloudflare tunnel needed yet — local-only is fine for v1.

### 4. (Later, not blocking) Run `sqlc generate` and migrate handlers from raw pgx to dbgen types. The queries file at `queries/certs.sql` is ready.

---

## Open future-features list (parked, not for next session)

User wants these eventually but they aren't part of the immediate wiring:
- Cross-tabulate centering analyses by grade: "how many PSA 9 vs PSA 10 scans have we done on this card?"
- Identify common centering patterns that prevent PSA 10 ("worst axis tends to be vertical/top for this card").
- For market data (PSA 9 price, PSA 10 price, gem rate) → entirely market-tracker's responsibility; slab cracker just joins on `display_key`.

---

## Quick context for new session

The `fg-collect-core` pattern is the canonical Go backend layout — slab cracker follows it exactly. Schema = 3 tables (no card_catalog, dropped in favor of display_key link). API auth = Bearer token, public reads, gated writes. All 4 decisions resolved (see `projects/slab-cracker/DECISIONS.md`). Phase 1+2 of `projects/slab-cracker/TODO.md` are done (T-001 through T-008). Next session starts at T-009.

To resume:
```
"pick up where we left off on slab cracker — extension wiring"
```
