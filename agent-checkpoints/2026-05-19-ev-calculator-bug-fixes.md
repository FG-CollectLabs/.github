# Agent Checkpoint — 2026-05-19

## What we worked on

### 1. EV Calculator — `ev-api.futuregadgetlabs.com` fetch failure

**Symptom:** `https://ev-calculator.futuregadgetlabs.com/commander/` loaded but every
display row showed an error; the display detail page returned 502.

**Root cause A — market-tracker-backend SQL bug (FIXED + DEPLOYED)**
- File: `market-tracker-backend/internal/prices/handler.go` line 285
- A stray `t` character in the sealed-snapshots batch SQL caused Postgres to return
  `syntax error at or near "."` on every `POST /v1/prices/batch` call.
- Introduced by commit `bb66a6e` ("prices: expose add_back_units_week in batch endpoint").
- Fix committed as `82cdb4a`, pushed to `master`, CI built and deployed to LXC 109.

**Root cause B — ev-calculator FallbackPricer swallowed primary error (FIXED + DEPLOYED)**
- File: `ev-calculator/internal/pricing/fallback.go` lines 18–19
- When the primary pricer (MarketTracker) returned an error, `FallbackPricer.Lookup`
  returned the error immediately instead of falling back to TCGCSV.
- Fixed to log the primary failure and call `f.Fallback.Lookup` with all original requests.
- Committed as `7fee3f3`, pushed to `main`, CI built and deployed to LXC 109.

**Root cause C — commander-display.js TDZ crash (FIXED, pages deploy in progress)**
- File: `ev-calculator/frontend/static/js/commander-display.js`
- `scryfallCache` (was line 786) and `TCG_IMG_BASE` (was line 858) were declared AFTER
  the first `renderDecks()` call at line 649. JavaScript's temporal dead zone caused a
  `ReferenceError` on every page load — decks silently never rendered.
- Introduced by the "Sellthrough analysis" commit (`9ebb364`).
- Fix: moved both `const` declarations to just after `$grid` (line 413), before the
  first `renderDecks()` call.
- Committed as `20f5caf`, pushed to `main`. GitHub Pages deploy was `in_progress` at
  handoff — should complete in ~20s. Verify at:
  `https://ev-calculator.futuregadgetlabs.com/commander/display/?key=blc-commander-display`

---

## Infrastructure context

- **LXC 109** (`fg-market-app`, `192.168.86.199`, on `proxmox3` at `192.168.86.92`)
  hosts both `market-tracker-backend` (port 8080) and `ev-calculator-api` (port 8081).
- SSH: `ssh -i ~/.ssh/id_ed25519_fg_proxmox root@192.168.86.92` then `pct exec 109 -- <cmd>`
- Docker images: `philwin/market-tracker-backend:latest`, `philwin/ev-calculator-api:latest`
- Env file for market-tracker: `/etc/market-tracker/env` on LXC 109
- ev-calculator-api env passed inline: `MARKET_TRACKER_BASE_URL=http://192.168.86.199:8080`
- CI: push to `master` → builds market-tracker image; push to `main` (touching
  `cmd/**`, `internal/**`, `Dockerfile`) → builds ev-calculator image;
  push to `main` (touching `frontend/**`) → deploys GitHub Pages

---

## What to verify next

1. **Confirm pages deploy succeeded** — check the commander display page renders deck
   cards with card tables visible (not just headers). Run:
   ```
   gh run list --repo FG-CollectLabs/ev-calculator --workflow pages.yml --limit 1
   ```

2. **Smoke-test the full flow:**
   - `https://ev-calculator.futuregadgetlabs.com/commander/` → rows should show case
     cost, singles net, best scenario (not error cells)
   - Click any case → should show deck cards with full card table expanded
   - Card images should load (proxied through `ev-api.futuregadgetlabs.com/v1/images/`)

3. **market-tracker-backend has other uncommitted changes** — unrelated in-progress work
   in the working tree (do NOT commit without Phil's direction):
   - `Dockerfile`, `go.mod`, `go.sum` modified
   - New: `cmd/ingest-ebay-scrape/`, `internal/ebayscrape/`, `internal/graded/`
   - New migration: `migrations/0008_graded_vendor.sql`
   - Modified: `queries/graded.sql`
   This looks like the **Graded Regrade Tracker** feature in progress (see project memory).

---

## Repos touched

| Repo | Branch | Last commit |
|------|--------|-------------|
| `FG-CollectLabs/market-tracker-backend` | `master` | `82cdb4a` prices: fix stray t-char SQL bug |
| `FG-CollectLabs/ev-calculator` | `main` | `20f5caf` commander-display: fix TDZ crash |
