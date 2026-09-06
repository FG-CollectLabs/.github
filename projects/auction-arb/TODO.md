# Auction Arb — TODO

Prereq for anything scheduled: **fix the self-hosted runner SSH** so
`.github/workflows/ingest.yml` can reach the Docker host. New cron entries are
dead weight until then. See `market-tracker-ingest-cron-broken` notes.

## Phase 0 — validate the source (half a day, do this first)

- [ ] AA-001 Run the Apify actor `jungle_synthesizer/fanaticscollect-weekly-auction-scraper`
      once by hand against the Clefairy #94 query. Confirm it returns the 4 Pristine
      + 5 Gem Mint split you can see in the UI.
- [ ] AA-002 Confirm the actor's `past auctions` mode returns the prior week
      (6 Pristine / 10 Gem Mint). If it cannot backfill, Phase 2 loses its history
      and the plan needs rework — find out now.
- [ ] AA-003 Record actual per-run cost for a 20-card watchlist. If it is not
      single-digit dollars/month, revisit the Playwright decision immediately.
- [ ] AA-004 Confirm `buyers_premium_pct` is populated and check the current
      Fanatics BP rate against a real invoice.

## Phase 1 — see the supply

### Schema
- [ ] AA-010 Migration `0014_auctions.sql`: enums, `auctions`, `auction_lots`,
      `auction_lot_snapshots`, `auction_sales`, `auction_supply_weekly`
- [ ] AA-011 `ALTER TABLE graded_watchlist ADD auction_query, auction_grade_keys`
- [ ] AA-012 Seed watchlist with ~20 cards — recent Pokémon set hits, Clefairy #94
      Perfect Order included as the reference case

### Scraper (`sellthrough-analyzer`)
- [ ] AA-020 `sources/fanatics.py`: `FanaticsSource` protocol + `ApifySource` impl
- [ ] AA-021 Title parser → `grade_key`; must split `CGC 10 PRISTINE` from `CGC 10`.
      Unit tests with real titles including the awkward ones.
- [ ] AA-022 `sellthrough fanatics census --watchlist <yaml>` CLI
- [ ] AA-023 Worker job type `fanatics-census`; push to `/v1/admin/auctions/bulk`
- [ ] AA-024 Config file `config/auction-watch.yaml` mirroring `graded-watch.yaml`

### Backend (`market-tracker-backend`)
- [ ] AA-030 `internal/auctions`: bulk upsert handler (model on `graded.upsertRows`)
- [ ] AA-031 `POST /v1/admin/auctions/bulk`
- [ ] AA-032 `GET /v1/auction-watch` — lot counts + baseline, no pricing yet
- [ ] AA-033 `GET /v1/cards/{display_key}/auction-supply`
- [ ] AA-034 `cmd/ingest-auctions` with `--mode=census`
- [ ] AA-035 Alert path: watched card returning 0 lots in an open auction

### Verify
- [ ] AA-040 Compare API output against the two Fanatics URLs by hand. Counts must
      match exactly before building anything on top.

## Phase 2 — price the flood

- [ ] AA-050 `--mode=history`: sales-history + past-auctions backfill
- [ ] AA-051 `--mode=close`: realized hammer + BP into `auction_sales`
- [ ] AA-052 `--mode=live`: hourly bid snapshots in the closing window
- [ ] AA-053 `cmd/compute-auction-signals`: baseline, flood_ratio, flood_z,
      competing_supply
- [ ] AA-054 Expected-discount bucketing; suppress below 3 samples per bucket
- [ ] AA-055 Join PriceCharting comp + gem rate; all-in vs net resale
- [ ] AA-056 `break_even_graded_price` from gem rate + raw price
- [ ] AA-057 Max-bid calculation with BP and shipping
- [ ] AA-058 Cron entries for census / live / close
- [ ] AA-059 Frontend: Auction Watch page + weekly supply sparkline

## Phase 3 — get ahead of it

- [ ] AA-070 Pop-report velocity (`Δ pop_count/week`) as a leading flood indicator
- [ ] AA-071 Discord alerts on the `internal/lotscout` notification pattern
- [ ] AA-072 Backtest: would the flagged weeks actually have been profitable?
- [ ] AA-073 Tune the 0.5 adjacent-tier competing-supply weight against real data
- [ ] AA-074 Second auction house (Goldin or PWCC) to prove the schema generalizes

## Open questions

- [ ] Does Fanatics sales-history cover Pristine and Gem Mint as separate titles,
      or does it collapse them? The URL you shared suggests separate — verify.
- [ ] Shipping cost per lot: flat, or per-item? Affects max bid materially on
      cheap cards.
- [ ] Is there a seller-side angle worth modelling — consigning into a *thin*
      week rather than buying into a flooded one?
