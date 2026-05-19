# Agent Checkpoint — 2026-05-19
## Graded Regrade Tracker — In-Progress WIP

---

## Status

Work-in-progress code exists **uncommitted** in `FG-CollectLabs/market-tracker-backend` on `master`.
No PR, no deployment. Do NOT commit without Phil's direction.

---

## Uncommitted changes in market-tracker-backend

| Path | What |
|---|---|
| `cmd/ingest-ebay-scrape/` | New binary — ingests eBay sold data from Apify scraper |
| `internal/ebayscrape/` | eBay scrape parsing logic |
| `internal/graded/` | Graded card domain logic |
| `migrations/0008_graded_vendor.sql` | New migration — graded vendor schema |
| `queries/graded.sql` | sqlc queries for graded domain |
| `Dockerfile` | Modified (likely adds new binary or deps) |
| `go.mod` / `go.sum` | New dependencies |

---

## Project context

See memory: `project_graded_regrade_tracker.md` — personal buy→grade→sell P&L tracker.

- **Goal:** Go CLI + PG `graded_tracker` DB; joins market-tracker for market context at report time.
- **Planning docs:** `.github/projects/graded-regrade-tracker/`
- **Database:** `graded_tracker` schema on Proxmox PG (see `pg-servers.json`).
- This is an **extension of market-tracker-backend**, not a new repo.

---

## Relationship to Slab Cracker backend

These are separate projects:
- **Slab Cracker backend** — centering analysis persistence + cert lookup; own Go service + own PG DB.
- **Graded Regrade Tracker** — buy/grade/sell P&L; lives inside market-tracker-backend; shares the market price DB for market context at report time.

Check `2026-05-19-slab-cracker-backend-planning.md` for Slab Cracker open decisions (still needs Phil sign-off).

---

## What to do next

1. Phil to review uncommitted changes and confirm direction.
2. Decide: keep in market-tracker-backend or spin into own service.
3. Run `migrations/0008_graded_vendor.sql` against `graded_tracker` DB on Proxmox.
4. Commit in a clean branch; CI builds the image.
