# Graded Market Watch — TODO

Work lives in `market-tracker-backend`. All tasks extend the existing graded layer.

---

## Phase 1 — Schema & gem rate (market-tracker-backend)

- [ ] Write migration `0008_graded_gem_rate.sql` — add `pop_total INTEGER` to `graded_snapshots_weekly`
- [ ] Write migration `0009_graded_views.sql` — create `graded_gem_rates` view
- [ ] Write migration `0010_graded_watchlist.sql` — create `graded_watchlist` table + `last_signal` enum
- [ ] Add sqlc queries for watchlist (`UpsertWatchlistEntry`, `ListWatchlist`, `DeleteWatchlistEntry`)
- [ ] Add sqlc queries for gem rates (`LatestGemRateForCard`, `ListGemRatesForSet`)
- [ ] Run `sqlc generate` and verify generated code compiles

---

## Phase 2 — Pop report ingest

- [ ] Research PSA pop report scraping — determine if psacard.com/pop is scrapeable or if a paid API key is needed
- [ ] Build `cmd/ingest-psa-pop/main.go`
  - [ ] Accept `--set` and optional `--card` flags
  - [ ] Fetch pop report page, parse pop_count per grade + pop_total
  - [ ] Upsert into `graded_snapshots_weekly` via `UpsertGradedSnapshot`
- [ ] Build `cmd/ingest-cgc-pop/main.go`
  - [ ] Same interface as PSA
  - [ ] Parse CGC pop report (different URL/HTML structure)
- [ ] Manual test against one card (e.g., a Strixhaven foil with known PSA pop)

---

## Phase 3 — Graded price ingest

- [ ] Evaluate PriceCharting API — confirm PSA 10 historical endpoint, check rate limits and auth
- [ ] Build `cmd/ingest-graded-prices/main.go`
  - [ ] PriceCharting adapter for PSA 10 prices
  - [ ] Apify eBay sold adapter for PSA 9, CGC 10 (reuse Apify account from eBay raw price work)
  - [ ] Write snapshots for grades `'9'`, `'10'` per company
- [ ] Test with 3–5 watched cards end-to-end

---

## Phase 4 — Signal computation

- [ ] Build `cmd/compute-graded-signals/main.go`
  - [ ] For each watchlisted card: fetch latest PSA 9, PSA 10, CGC 10 prices and gem rates
  - [ ] Compute `undervalued_10` signal: gem_rate < threshold AND psa10_price / psa9_price < multiplier_threshold
  - [ ] Compute `regrade_candidate_9` signal: (psa10_price - psa9_price) > (grading_fee * gem_rate_adjustment)
  - [ ] Update `graded_watchlist.last_signal` and `last_signal_at`
  - [ ] Make thresholds configurable via env vars
- [ ] Wire signal thresholds into `internal/config/config.go`

---

## Phase 5 — API endpoints

- [ ] `GET /v1/cards/:id/gem-rate` handler in `internal/graded/handler.go`
- [ ] `GET /v1/watchlist/graded` handler in `internal/graded/handler.go`
- [ ] `POST /v1/watchlist/graded` handler
- [ ] `DELETE /v1/watchlist/graded/:card_id` handler
- [ ] Wire new routes in `cmd/api/main.go`
- [ ] Add openapi.yaml definitions for new endpoints

---

## Phase 6 — Weekly job wiring

- [ ] Add `ingest-psa-pop`, `ingest-cgc-pop`, `ingest-graded-prices`, `compute-graded-signals` steps to `.github/workflows/weekly-ingest.yml`
- [ ] Ensure steps run sequentially and fail-fast on error
- [ ] Add Dockerfile targets for each new cmd
- [ ] Smoke test full weekly run locally with `--dry-run` flag

---

## Parking lot

- Push graded snapshots to BigQuery via existing `cmd/sync bigquery` (once BQ sync is built)
- Telegram/email alert when a watchlisted card hits a signal
- Surface gem rate trend (is it getting harder or easier to gem?) from week-over-week pop_total delta
- CGC Pristine (10) vs Perfect (10) distinction — CGC has two 10 tiers; handle in grade column as `'10'` vs `'P10'`
