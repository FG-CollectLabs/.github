# Graded Market Watch — Architecture

## Purpose

Extend `market-tracker-backend` to provide a graded card market intelligence layer:

- Weekly PSA 9, PSA 10, CGC 10 price snapshots
- PSA Gem Rate and CGC Gem Rate per card
- Watchlist signals surfacing undervalued PSA 10s and PSA 9 regrade candidates

## Where this lives

This is **not a separate repo**. All data and ingest jobs live in `market-tracker-backend`.

The graded layer already exists (`graded_snapshots_weekly`, migration 0004). This project adds:

1. `pop_total` to the graded snapshot table (migration 0008)
2. Pop report scrapers (`cmd/ingest-psa-pop`, `cmd/ingest-cgc-pop`)
3. Graded price ingest (`cmd/ingest-graded-prices`) — eBay sold + PriceCharting
4. Watchlist table + API (`graded_watchlist`)
5. Watchlist signal computation (scheduled weekly)

## Gem Rate Definition

| Signal | Formula |
|---|---|
| PSA Gem Rate | PSA 10 `pop_count` / `pop_total` (all PSA grades summed) |
| CGC Gem Rate | CGC 10 `pop_count` / `pop_total` (all CGC grades summed) |

`pop_total` is sourced from the pop report and stored denormalized per row so each snapshot is self-contained. This avoids having to sum across all grade rows at query time.

## Data Sources

| Data | Source | Method |
|---|---|---|
| PSA pop report | psacard.com/pop | HTTP scrape — card name + set search |
| CGC pop report | cgccomics.com/pop-report | HTTP scrape |
| PSA marketplace prices | PriceCharting API | REST — has PSA 10 historical |
| CGC marketplace prices | eBay sold (Apify) | Apify actor — filter "CGC 10" in title |
| PSA 9 / PSA 10 raw prices | eBay sold (Apify) | Apify actor — filter by grade in title |

PriceCharting is the easiest starting point for PSA 10 prices (has historical data and a free tier). eBay sold via Apify covers CGC and raw-grade prices.

## Schema Changes (migration 0008)

```sql
ALTER TABLE graded_snapshots_weekly
  ADD COLUMN pop_total INTEGER CHECK (pop_total IS NULL OR pop_total >= 0);

-- Gem rate is computed at query time: pop_count::float / NULLIF(pop_total, 0)
-- No need to store it; avoids staleness if pop_total is backfilled.
```

A `gem_rate_pct` computed column is exposed via a database view:

```sql
CREATE VIEW graded_gem_rates AS
SELECT
  g.*,
  ROUND((g.pop_count::numeric / NULLIF(g.pop_total, 0)) * 100, 2) AS gem_rate_pct
FROM graded_snapshots_weekly g
WHERE g.grade IN ('10', 'Pristine 10');
```

## Watchlist

```sql
CREATE TABLE graded_watchlist (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id       UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  added_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  note          TEXT,
  -- Denormalized signals computed at last weekly run
  last_signal   TEXT,         -- 'undervalued_10', 'regrade_candidate_9', 'monitor'
  last_signal_at TIMESTAMPTZ,
  UNIQUE (card_id)
);
```

Signal computation runs as part of the weekly ingest job. Signals:

- `undervalued_10` — PSA 10 market price is below a configurable threshold vs gem difficulty (e.g., gem rate < 10% but price premium over PSA 9 is < 2×)
- `regrade_candidate_9` — PSA 9 price is low enough that upgrading to PSA 10 would be profitable after grading fees, factoring in gem rate
- `monitor` — explicitly added but no signal triggered yet

## API Surface (additions to market-tracker-backend)

| Method | Path | Description |
|---|---|---|
| GET | `/v1/cards/:id/graded` | All graded snapshots for a card (existing, extended) |
| GET | `/v1/cards/:id/gem-rate` | Latest gem rate per company |
| GET | `/v1/watchlist/graded` | All watchlist entries with current signals |
| POST | `/v1/watchlist/graded` | Add card to watchlist |
| DELETE | `/v1/watchlist/graded/:card_id` | Remove from watchlist |

## Ingest Commands

| Command | Cadence | Source |
|---|---|---|
| `cmd/ingest-psa-pop` | Weekly | PSA pop report website |
| `cmd/ingest-cgc-pop` | Weekly | CGC pop report website |
| `cmd/ingest-graded-prices` | Weekly | PriceCharting + Apify eBay |
| `cmd/compute-graded-signals` | Weekly (after above) | Local DB computation |

All four run sequentially in the weekly GitHub Actions workflow, after the existing raw price ingest.

## Deployment

Same Proxmox homelab setup as the rest of market-tracker-backend. The weekly GitHub Actions cron calls each `cmd/*` via Docker. No new infrastructure required.
