# Slab Cracker — TODO

Status legend: `[ ]` open · `[~claimed: <agent> <date>]` in-progress · `[x]` done · `[!]` blocked · `[-]` cancelled

---

## Phase 1 — Backend scaffolding

- [x] T-001 Create `slab-cracker-backend` repo under FG-CollectLabs, scaffold Go module following fg-collect-core pattern (cmd/api, internal/, go.mod)
- [x] T-002 Stand up Postgres DB on Proxmox homelab for slab-cracker; entry already present in `pg-servers.json`. `fg_app` role created, DB created, DML + default privileges granted.
- [x] T-003 Write initial schema migration: `certs`, `cert_scans`, `centering_analyses` tables (no `card_catalog` — use `display_key` instead, see DECISIONS.md D-004). Applied via goose.
- [x] T-004 Write sqlc queries in `queries/certs.sql` (upsert cert, upsert cert_scans, insert + list analyses, trend by display_key). `sqlc generate` deferred — v1 handlers use raw pgx.

## Phase 2 — Backend API endpoints

- [x] T-005 `GET /v1/certs/{cert_number}` — return cert + scans + all centering analyses if present; 404 if not
- [x] T-006 `POST /v1/certs/{cert_number}` — upsert cert metadata + scans (Bearer auth)
- [x] T-007 `POST /v1/certs/{cert_number}/analyses` — save a new centering analysis (Bearer auth)
- [x] T-008 `GET /v1/cards/{display_key}/analyses` — return all analyses for a given card (trend view)

## Phase 3 — Extension integration

- [ ] T-009 After a successful PSA/CGC scrape, extension POSTs cert metadata + scan URLs to backend (`POST /v1/certs/{cert_number}`)
- [ ] T-010 On cert lookup request from frontend, extension first checks `GET /v1/certs/{cert_number}` — if backend has it, return cached data without re-scraping
- [ ] T-011 Extension options page: backend URL + Bearer token fields

## Phase 4 — Frontend integration

- [ ] T-012 On image load + cert detection, frontend calls backend `GET /v1/certs/{cert_number}` before requesting extension scrape
- [ ] T-013 After user saves a session, frontend POSTs centering analysis to backend (`POST /v1/certs/{cert_number}/analyses`)
- [ ] T-014 Add "History" panel to frontend: show all saved analyses for the current cert number, pulled from backend
- [ ] T-015 Add "Trend" view: for a given card (by `display_key`), show distribution of centering across all analyzed certs

## Phase 5 — Crack decision tooling

- [ ] T-016 Crack recommendation signal: combine slab cracker's PSA ceiling with market-tracker's `/v1/cards/{display_key}/graded` PSA9→PSA10 price delta. Surface "worth cracking" when ceiling > current grade AND `(psa10 - psa9) > $25`.
- [ ] T-017 Watchlist: user can flag a cert as "watching" — surfaced on next load with prior analysis pre-loaded.
- [ ] T-018 (Later) Run `sqlc generate` and migrate handlers from raw pgx to dbgen-typed queries.
