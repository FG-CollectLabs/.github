# Graded Tracker — TODO

See [ARCHITECTURE.md](ARCHITECTURE.md). Start with ME1.

## Phase 0 — homelab (blocks automated PriceCharting only, not manual entry)

- [ ] GT-001 Provision the runner SSH key on LXC 109 + `known_hosts` for `.199`
- [x] GT-002 Deploy `sellthrough-worker` on `.199:8001` (2026-10-05; image fixed in analyzer PR #2)
- [ ] GT-003 `gh workflow run ingest.yml -f job=graded-prices` succeeds end to end

## Phase 1 — tracked list + manual entry

Built and tested locally 2026-09-30 against a copy of the prod ME1 catalog (enrichment:
188 cards + 122 reverse holos; sync: 64 tracked). **Deployed 2026-10-03** (prod at migration 16, API redeployed, ME1 enriched + synced: 64 tracked).

- [x] GT-090 Rotate `ADMIN_API_TOKEN` (done 2026-10-03; `VITE_ADMIN_API_KEY` removed from the Pages build and the `MT_ADMIN_API_KEY` secret deleted)
- [x] GT-091 `goose status` on prod, then `goose up` (0013 now has goose annotations and is
      idempotent; 0016 adds the tracker tables; prod needs `goose up --allow-missing` once, run as the table owner (its version 14 is lot-scout; 0015 is the snapshot-column fix from #7))
- [x] GT-092 Push backend `master` → image build → `./deploy.sh`
- [x] GT-093 On .199: `enrich-pokemon -set me1 -tcgdex me01`, then `sync-tracked`
- [x] GT-094 Register the MCP server locally (`docs/mcp.md`)
- [x] GT-095 Redeploy the worker image so console-prices picks up the Pristine / reverse-holo fixes

### Catalog
- [x] GT-010 `cmd/enrich-pokemon`: TCGdex → `cards.rarity`, `details.artist`, reverse-holo rows (`-rh`)
- [x] GT-011 Run for ME1; confirm 22 IR / 22 UR / 10 SIR / 2 MHR

### Tracking
- [x] GT-020 `internal/tracking/tracking.yaml` (sets, rarities, top-10 Pokémon, top-10 artists, finishes)
- [x] GT-021 Migration 0016: `tracked_cards`, `card_sales`, `card_supply_snapshots`, `card_sales_weekly`, `ingest_runs`
- [x] GT-022 `cmd/sync-tracked`: apply rules, respect pinned/excluded
- [x] GT-023 Verify ME1 = 64 tracked rows

### API
- [x] GT-030 `GET /v1/tracked?set=me1`: one row per card, all source columns + as-of dates
- [x] GT-031 `GET /v1/cards/{key}/sales?grade=&source=`
- [x] GT-032 `POST /v1/admin/sales/bulk`, `POST /v1/admin/supply`, `DELETE /v1/admin/sales/{id}`
- [x] GT-033 `PUT /v1/admin/tracked/{key}` (pin / exclude / note)
- [x] GT-034 `GET /v1/ingest-runs`: last success per source, stale flag

### MCP server
- [x] GT-040 `cmd/mcp` (stdio, go-sdk): `find_card`, `list_tracked`, `get_card`
- [x] GT-041 `record_sales`, `record_supply`, `delete_sale`, `track_card`
- [x] GT-042 Guardrails: grade_key enum, BP required for Fanatics, date sanity
- [x] GT-043 `.mcp.json` snippet + README for running it from Claude Code
- [ ] GT-044 Enter one real Fanatics week by hand; check it round-trips to the page

### PriceCharting fixes (`sellthrough-analyzer`)
- [x] GT-050 Keep `CGC 10 Pristine` → `('cgc', 'Pristine 10')`
- [x] GT-051 Reverse-holo slugs map to the `-rh` display_key instead of overwriting base
- [x] GT-052 Per-card page scrape for every tracked card (not just `graded_watch`)
- [x] GT-053 Make the raw-price join source-explicit in the backend

### Frontend
- [x] GT-060 "Tracked Cards" page: PC / eBay / Fanatics column groups, per-cell as-of, stale badges
- [x] GT-061 Card drill-down: sales list + weekly sold-count bars per source/grade
- [x] GT-062 Source-freshness strip from `/v1/ingest-runs`

## Phase 2 — automate what's stable

- [ ] GT-070 Weekly cron for PriceCharting over tracked cards (needs Phase 0)
- [ ] GT-071 eBay graded-sold scrape per tracked card+grade → `card_sales` (`entry_method='scraper'`)
- [ ] GT-072 Staleness alert (Discord, `lotscout` notify pattern) when a source misses its cadence

## Phase 3 — dump detection

- [ ] GT-080 `absorption_ratio` per card+grade+source; flag ≥3× and ≥10 copies
- [ ] GT-081 Competing supply across Pristine / Gem Mint 10
- [ ] GT-082 Gem-rate break-even to separate temporary dumps from repricing
- [ ] GT-083 Max-bid suggestion: all-in cost vs eBay net resale (13% fees)
- [ ] GT-084 Second auction house via the same MCP `source` field

## Phase 4 — bulk lots, Fanatics automation, Japanese, analytics

### Lot evaluator (`market-tracker-backend`) — deployed 2026-10-04 (PR #9, prod at migration 17)
- [x] GT-100 Migration 0017: `lots`, `lot_items`
- [x] GT-101 Valuation: market comp per item (Fanatics → eBay → PriceCharting), cost basis, net + profit for FanCash and cash
- [x] GT-102 Admin API: create/list/get lots, add/update items, evaluation summary
- [x] GT-103 MCP tools: `create_lot`, `add_lot_items`, `update_lot_item`, `evaluate_lot`, `list_lots`
- [x] GT-104 Realized P&L as items sell

### Fanatics automation (self-hosted, no Apify) — backend PR #11, not deployed
- [x] GT-110 Fanatics client: public sales-history API (sold; auction prices include 20% BP) + Algolia listings (key from anonymous GraphQL)
- [x] GT-111 Title parsing/matching on real titles: language from title, PRISTINE / BLACK LABEL, number, name, set, reverse holo
- [x] GT-112 `cmd/ingest-fanatics` → `card_sales` + `market_listings` (migration 0018) + supply counts; refresh endpoint + MCP `fanatics_refresh` / `fanatics_lookup`
- [x] GT-113 Weekly cron Monday 04:00 UTC
- [ ] GT-114 eBay sold + Buy Now: eBay returns 403 for the home IP (site and official API); needs a decision

### Japanese
- [x] GT-120 `import-jp` (not enrich): cards numbered above the official count = AR and better; 43 sets S9–M6, 1,662 cards (backend PR #10; deployed 2026-10-05, prod: 1,662 imported + tracked)
- [x] GT-121 English names from PriceCharting console JSON; console URL stored so console-prices prices them (per-card CGC scrape skipped for JP tracked cards, analyzer PR #1)
- [x] GT-122 `tracking.yaml`: `jp-*` + `track_all_sets`; frontend set filter (frontend PR #2)

### Grade 9
- [ ] GT-130 Stop storing PriceCharting "Grade 9" as PSA 9; keep it as an any-grader reference

### Analytics (`graded-analytics`, new repo)
- [ ] GT-140 Read-only Postgres role
- [ ] GT-141 Repo scaffold: notebooks + SQL, connection via env
- [ ] GT-142 First analyses: lot ROI distribution, sell-through by price band, Pristine vs Gem spread

## Open questions

- [ ] Current Fanatics buyer's premium rate (default for `record_sales`)
- [ ] Do eBay Best Offer sales count? eBay hides the accepted price; store list price with `sale_type='best_offer'` and exclude from medians?
- [ ] Add ME2–ME5 to `tracking.yaml` once ME1 looks right
