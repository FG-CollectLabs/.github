# Auction Arb — Architecture

Detect graded-card auction lots that will sell cheap because the market is
temporarily flooded with copies of the same card at the same grade, and size
a rational max bid against independent fair-value anchors.

**V1 source: Fanatics Collect** (weekly auctions). The model generalizes to
Goldin / PWCC / Heritage, so the schema is auction-house agnostic from day one.

## The thesis

Fanatics weekly auctions close simultaneously. If nine CGC 10 copies of the same
card close on the same night, the ninth-highest bidder sets the clearing price —
so realized price collapses even though nothing about the card changed. That
collapse is temporary: submissions ebb, and the next week's two copies sell at
the normal price.

The edge is buying the flooded week and selling into a normal one. To act on it
we need three numbers per card+grade:

1. **How flooded is this week** vs its own trailing baseline.
2. **How much cheaper** lots historically clear at that level of supply.
3. **What the card is actually worth** from sources independent of Fanatics
   (eBay comps via PriceCharting, and a grading-EV floor from the pop report).

## What already exists — reuse, do not rebuild

| Capability | Where it lives today |
|---|---|
| `cards` / `sets` catalog, `display_key` resolution | `market-tracker-backend` (migration 0002) |
| Weekly graded prices per company+grade, incl. `'Pristine 10'` | `graded_snapshots_weekly` (0004, 0008) |
| Pop counts + `pop_total` + `graded_gem_rates` view | migration 0008 |
| PSA / CGC pop report scrapers | `sellthrough-analyzer` — `psa-pop`, `cgc-pop` |
| PriceCharting console scraper (raw + PSA + CGC prices) | `sellthrough-analyzer` — `console-prices` |
| Playwright job-queue worker + `/jobs` API | `sellthrough-analyzer` worker on LXC 109 (`docs/worker.md`) |
| Bulk upload endpoint scrapers push results to | `POST /v1/admin/graded/bulk` |
| Marketplace-scan → dedupe → analyze → Discord pattern | `internal/lotscout` (~950 LOC, the size precedent) |
| Grading ROI / EV math | `internal/graded` + frontend `src/lib/roi.ts` |
| Weekly cron → self-hosted runner → docker run | `.github/workflows/ingest.yml` |

The gem rate, the eBay comp, and the ROI math are **already built**. The genuinely
new thing is auction supply: nobody is counting concurrent lots.

## Repo decision: zero new repos

Extend three existing repos rather than standing up a fourth service.

| Repo | Addition |
|---|---|
| `sellthrough-analyzer` (Python) | `fanatics` source module + three new worker job types |
| `market-tracker-backend` (Go) | migration 0014, `internal/auctions`, `cmd/ingest-auctions`, `cmd/compute-auction-signals`, API routes |
| `market-tracker-frontend` (React) | "Auction Watch" page |

**Why not a standalone `fanatics-arb` service:** every metric that matters is a
join between auction supply and data that already lives in `market_tracker` —
gem rate, PriceCharting comps, the card catalog. A separate service turns the
core query into a cross-service fan-out and forces a duplicate card catalog.
The one precedent here is decisive: `lot-scout` was planned as its own repo and
was ultimately built as `cmd/lot-scout` inside `market-tracker-backend`.

**Why the scraping still goes in `sellthrough-analyzer`:** it is already the
browser-automation arm, already deployed with a job queue, and already the thing
that pushes results back over the admin bulk API. Fanatics is a JS-heavy,
bot-protected site; Go + an HTTP client is the wrong tool.

**Revisit if:** Fanatics scraping needs its own scaling/proxy budget, or a second
auction house lands and the ingest outgrows one command.

## Data access reality (verified 2026-09-06)

| Target | Status |
|---|---|
| `sales-history.fanaticscollect.com` | **HTTP 403** to plain fetch — bot protected |
| `pricecharting.com` card page | **HTTP 403** to plain fetch — but already solved in-house via Playwright `console-prices` |
| Official Fanatics Collect API | none found; no public developer portal |
| Apify `jungle_synthesizer/fanaticscollect-weekly-auction-scraper` | works; pay-per-event |

The Apify actor returns exactly the fields this project needs: lot ID, URL,
auction type, title, year, card number, grader, numeric grade, **bid count**,
**watchers**, current bid, opening bid, **final sale price**, **buyer's premium
percent**, currency, status, image URLs, auction end date — with a **past
auctions** mode for backfill.

### Scraper decision: start on Apify, behind an interface

The project is worthless until there are 8–12 weeks of supply baseline. Do not
spend the first month fighting Cloudflare; spend it proving the signal exists.

Define a `FanaticsSource` protocol in `sellthrough-analyzer` with two
implementations — `ApifySource` (V1) and `PlaywrightSource` (later) — selected by
env var. With a tight watchlist and weekly cadence the Apify spend is a few
dollars a month. Self-host once the signal is validated and the cost or the
dependency actually bites. (Precedent: eBay ingest started on Apify and was
migrated to a self-hosted scraper once it was worth owning.)

## Card resolution: watchlist-driven, not title-parsing

Fanatics titles are freeform: `2026 Pokemon Mega Evolution Perfect Order IR
Clefairy #94 CGC 10`. Parsing arbitrary titles into `cards.id` is the classic
silent-failure mode for this kind of pipeline.

Invert it. The watchlist is tight and hand-curated (recent Pokémon sets, hits
only), so **drive the scrape from the watchlist**: for each watched card+grade,
issue the Fanatics search query and attribute every returned lot to that card.
This mirrors exactly what you do by hand today with the `q=` parameter, and it
means a miss shows up as "zero lots found," which is auditable, rather than as a
lot silently attributed to the wrong card.

Store `title_raw` on every lot regardless, plus an `unresolved_lots` view, so
query drift is visible.

### Pristine 10 vs Gem Mint 10

CGC issues both at numeric grade 10 and they are different markets. The scraper's
`grade` field is numeric, so the Pristine qualifier must be parsed out of the
title (Fanatics writes `CGC 10 PRISTINE`). Model it as a `grade_key` string —
`cgc-10-pristine`, `cgc-10`, `cgc-9.5`, `psa-10` — not as a float. The existing
`graded_snapshots_weekly.grade` column already carries `'Pristine 10'`, so this
is consistent with the graded layer.

The two tiers also **compete** for the same bidders. Track them separately but
compute a `competing_supply` that weights the adjacent tier (start at 0.5, make
it a tunable constant, revisit once there is data).

## Schema — migration 0014

Migration numbering note: the repo jumps 0011 → 0013; there is no 0012. Next free
number is **0014**.

```sql
CREATE TYPE auction_house AS ENUM ('fanatics');
CREATE TYPE auction_kind  AS ENUM ('weekly', 'premier', 'fixed', 'vault');

-- One auction event (a specific weekly sale).
CREATE TABLE auctions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  house        auction_house NOT NULL,
  external_id  TEXT NOT NULL,           -- e.g. 'WEEKLY:8aacfd8a-13cb-11f1-...'
  kind         auction_kind  NOT NULL,
  name         TEXT,
  opens_at     TIMESTAMPTZ,
  closes_at    TIMESTAMPTZ,
  UNIQUE (house, external_id)
);

-- One lot. card_id NULL = unresolved (should be rare under watchlist-driven scrape).
CREATE TABLE auction_lots (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auction_id        UUID NOT NULL REFERENCES auctions(id) ON DELETE CASCADE,
  external_lot_id   TEXT NOT NULL,
  card_id           UUID REFERENCES cards(id) ON DELETE SET NULL,
  title_raw         TEXT NOT NULL,
  grade_key         TEXT,               -- 'cgc-10-pristine', 'psa-10', ...
  company           grading_company,    -- reuse existing enum
  cert_number       TEXT,
  url               TEXT,
  image_url         TEXT,
  opening_bid_cents INTEGER,
  closes_at         TIMESTAMPTZ,
  first_seen_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (auction_id, external_lot_id)
);

-- Bid development during the live window.
CREATE TABLE auction_lot_snapshots (
  lot_id            UUID NOT NULL REFERENCES auction_lots(id) ON DELETE CASCADE,
  captured_at       TIMESTAMPTZ NOT NULL,
  current_bid_cents INTEGER,
  bid_count         INTEGER,
  watchers          INTEGER,
  PRIMARY KEY (lot_id, captured_at)
);

-- Realized results. Also the landing table for sales-history backfill,
-- where lot_id may be NULL because only the sale is known.
CREATE TABLE auction_sales (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lot_id             UUID REFERENCES auction_lots(id) ON DELETE SET NULL,
  house              auction_house NOT NULL,
  card_id            UUID REFERENCES cards(id) ON DELETE SET NULL,
  grade_key          TEXT,
  sold_at            TIMESTAMPTZ NOT NULL,
  hammer_cents       INTEGER NOT NULL,
  buyers_premium_pct NUMERIC(5,2),
  all_in_cents       INTEGER,           -- hammer * (1 + BP); shipping excluded
  title_raw          TEXT,
  source             TEXT NOT NULL,     -- 'lot_close' | 'sales_history'
  UNIQUE (house, source, title_raw, sold_at, hammer_cents)
);

-- Weekly rollup + signals. Recomputed, not incrementally updated.
CREATE TABLE auction_supply_weekly (
  card_id             UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  grade_key           TEXT NOT NULL,
  week_start_date     DATE NOT NULL,
  house               auction_house NOT NULL,
  lot_count           INTEGER NOT NULL,
  competing_supply    NUMERIC(6,2),     -- lot_count + 0.5 * adjacent tier
  sold_count          INTEGER,
  median_hammer_cents INTEGER,
  median_all_in_cents INTEGER,
  baseline_lot_count  NUMERIC(6,2),     -- trailing median, >= 6 weeks
  flood_ratio         NUMERIC(6,2),
  flood_z             NUMERIC(6,2),
  PRIMARY KEY (card_id, grade_key, week_start_date, house)
);
```

Watchlist reuse: extend the existing `graded_watchlist` with the grade tiers and
Fanatics query string to track, rather than creating a second watchlist table.

```sql
ALTER TABLE graded_watchlist
  ADD COLUMN auction_query TEXT,             -- the Fanatics q= string
  ADD COLUMN auction_grade_keys TEXT[];      -- {'cgc-10-pristine','cgc-10'}
```

## Metrics

### 1. Flood detection

```
lot_count(card, grade_key, week)          -- this week's concurrent supply
baseline    = median(lot_count, trailing 8-12 weeks, excluding current)
flood_ratio = lot_count / max(baseline, 1)
flood_z     = (lot_count - mean) / stddev  -- prefer over ratio at low counts
```

Flag when `flood_ratio >= 2` **and** `lot_count >= 4`. The absolute floor matters:
1 → 2 lots doubles the ratio but does not move a clearing price.

### 2. Expected discount — "how much cheaper"

With sparse per-card history, do not fit a curve. Bucket:

```
normal_price  = median(all_in) over weeks where lot_count <= baseline
flooded_price = median(all_in) over weeks where lot_count >= 2 * baseline
expected_discount_pct = 1 - flooded_price / normal_price
```

Report the sample size alongside it. Below ~3 observations per bucket, show the
supply number and suppress the discount estimate rather than publishing noise.
Pool across cards within a set+rarity tier for a prior once there is enough data.

### 3. Fair value anchors (independent of Fanatics)

```
pc_price        = PriceCharting CGC 10 comp        (existing console-prices)
ebay_net        = pc_price * (1 - 0.13)            -- fees on resale
fanatics_all_in = hammer * (1 + buyers_premium) + shipping
```

**Buyer's premium is where these models manufacture fake edge.** Fanatics hammer
price is not what you pay. Every comparison must be all-in cost vs net resale
proceeds. The scraper returns `buyers_premium_pct` — persist it per sale and
never compare a hammer price to an eBay ask.

The `fanatics_all_in / ebay_net` ratio is itself a stable per-card constant worth
tracking; it is the structural discount for buying at auction, distinct from the
flood discount we are hunting.

### 4. Grading-EV floor — why floods happen and when they end

```
gem_rate    = cgc10_pop / cgc_total_pop          (existing graded_gem_rates view)
ev_of_grade = gem_rate * P(CGC 10) + (1 - gem_rate) * P(CGC 9.5) - fee
break_even_graded_price = (raw_price + fee) / gem_rate
```

When the market price of the CGC 10 falls below `break_even_graded_price`,
submitting is unprofitable, submissions contract, and supply mean-reverts. That
is the strongest available evidence the discount is temporary rather than a
repricing — which is the single distinction this whole project turns on.

### 5. Bid recommendation

```
expected_resale_net = median normal-week all_in, or ebay_net, whichever is lower
max_bid_hammer = (expected_resale_net * (1 - target_margin)) / (1 + bp) - shipping
```

### 6. Pop-report velocity as a *leading* indicator

Everything above is reactive — it sees the flood the week it lands. Pop reports
are already ingested weekly, so `Δ pop_count / week` is nearly free and predicts
floods roughly 4–8 weeks ahead of the auction. A spike in newly registered CGC 10s
is the submission wave that becomes next month's oversupply. Worth building in
Phase 3; it is the part that turns this from a screener into an early warning.

## Ingest commands and cadence

Fanatics weekly auctions open around Thursday and close Sunday/Monday night.

| Command | Cadence | Purpose |
|---|---|---|
| `cmd/ingest-auctions --mode=census` | Thu, at open | **The actionable one.** Count supply before bidding heats up |
| `cmd/ingest-auctions --mode=live` | hourly, final 3h | Bid/watcher development into `auction_lot_snapshots` |
| `cmd/ingest-auctions --mode=close` | Mon, after close | Realized hammer + BP into `auction_sales` |
| `cmd/ingest-auctions --mode=history` | one-off / monthly | Backfill from sales-history + past-auctions mode |
| `cmd/compute-auction-signals` | Mon, after close | Rebuild `auction_supply_weekly` |

**Hard dependency:** the weekly ingest cron is currently broken — the self-hosted
runner cannot SSH to the Docker host (missing key, `Host key verification failed`).
Every job above inherits that breakage. Fix the runner before Phase 1 ships, or
these are cron entries that never fire.

## API surface (`market-tracker-backend`)

| Method | Path | Description |
|---|---|---|
| GET | `/v1/auctions` | Recent auctions with lot counts |
| GET | `/v1/auctions/{id}/lots` | Lots in one auction, joined to card + gem rate |
| GET | `/v1/auction-watch` | **Main screen.** Watched cards for the open auction with flood + discount + max bid |
| GET | `/v1/cards/{display_key}/auction-supply` | Weekly supply history for one card+grade |
| POST | `/v1/admin/auctions/bulk` | Scraper upload (mirrors `/v1/admin/graded/bulk`) |
| PUT | `/v1/admin/watchlist/{card_id}/auction` | Set `auction_query` + `auction_grade_keys` |

## Frontend

One new page in `market-tracker-frontend`: **Auction Watch**. A table over
`/v1/auction-watch`, sorted by opportunity, with columns for supply this week,
baseline, flood ratio, expected discount, gem rate, eBay comp, and suggested max
bid — plus a sparkline of weekly supply per card. Reuse the existing table and
rarity-filter patterns from `SetDetailPage`.

## Risks

| Risk | Mitigation |
|---|---|
| Fanatics blocks scraping / Apify actor breaks | `FanaticsSource` interface; Apify and Playwright both implementable |
| Not enough history to estimate discount | Backfill via past-auctions + sales-history; suppress the estimate below 3 samples |
| Pristine/Gem Mint conflated | `grade_key` string, parsed from title, never a float |
| Buyer's premium ignored → phantom arbitrage | Persist BP per sale; all-in vs net everywhere |
| Watchlist query drift returns 0 lots silently | Alert on watched cards with 0 results in an open auction |
| Thin per-card samples → overfitting | Bucket, do not fit; pool by set+rarity for priors |
| Broken ingest cron | Fix runner SSH first — see hard dependency above |

## Phasing

- **Phase 1 — see the supply.** Migration 0014, Apify census scrape for a ~20-card
  watchlist, `/v1/auction-watch` returning lot counts and baseline only. No
  pricing model. Goal: confirm the counts match what you see by hand.
- **Phase 2 — price the flood.** Backfill history, `auction_sales`, expected
  discount, all-in vs eBay-net comparison, max bid. Auction Watch page.
- **Phase 3 — get ahead of it.** Pop-report velocity as a leading indicator,
  Discord alerts on the `lot-scout` notification pattern, second auction house.
