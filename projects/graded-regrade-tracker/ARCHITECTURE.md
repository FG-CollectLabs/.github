# Graded Regrade Tracker — Architecture

## Purpose

A personal investment workflow tool for the buy → analyze → grade → sell cycle on trading cards.
Tracks the full P&L on regrade ventures: what you paid, what it graded at, what it sold for, and
what the market looked like when you bought.

## Key Design Decisions

**Join market data by date, don't snapshot it at purchase time.**
PSA/CGC prices and gem rates at time of purchase come from `market-tracker-backend` joined by
`purchased_at` date. The purchase record stores the card reference and purchase date; a query to
market-tracker gives the contemporaneous market context. This keeps the two systems loosely coupled
and avoids stale denormalized data.

**Grading fees stored explicitly.**
Fee schedules change and vary by service level. Store `submission_fee_cents` per submission, not
derived from any lookup.

**One purchase → one or more submissions.**
A PSA 9 might be cracked, cleaned, and resubmitted to CGC. Each submission is a separate row.
A purchase can also produce multiple results if a submission contains multiple cards (e.g., bulk
submissions handled via a `submission_batch`).

**CLI-first v1, API + dashboard later.**
v1 is a Go CLI (`cmd/add`, `cmd/list`, `cmd/report`) backed by PostgreSQL. No HTTP server in v1.
Hugo dashboard is a v2 concern once data volume justifies visualization.

## Repo

`FG-CollectLabs/graded-regrade-tracker`

Stack: Go + pgx/sqlc + PostgreSQL (same Proxmox instance as market-tracker)

## Schema

```sql
-- Cards being tracked. References market-tracker by external ID for joins.
CREATE TABLE tracked_cards (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game                   TEXT NOT NULL,           -- 'mtg', 'pokemon', 'yugioh'
  set_code               TEXT NOT NULL,
  card_number            TEXT NOT NULL,
  card_name              TEXT NOT NULL,
  variant                TEXT,                    -- 'foil', 'holo', etc.
  market_tracker_card_id UUID,                    -- soft reference; nullable
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (game, set_code, card_number, COALESCE(variant, ''))
);

-- A card purchase (raw or already graded)
CREATE TABLE purchases (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tracked_card_id      UUID NOT NULL REFERENCES tracked_cards(id),
  purchased_at         DATE NOT NULL,
  platform             TEXT NOT NULL,             -- 'ebay', 'tcgplayer', 'local', 'show'
  seller               TEXT,
  purchase_price_cents INTEGER NOT NULL CHECK (purchase_price_cents > 0),
  quantity             INTEGER NOT NULL DEFAULT 1,
  incoming_grade       TEXT,                      -- null = raw; 'PSA 9' = already graded
  condition_notes      TEXT,                      -- buyer's eye test
  listing_url          TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pre-grading analysis — recorded before submitting
CREATE TABLE pre_grading_analyses (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id          UUID NOT NULL REFERENCES purchases(id),
  analyzed_at          DATE NOT NULL,
  centering            NUMERIC(3,1),              -- 0–10 subjective score
  surface              NUMERIC(3,1),
  edges                NUMERIC(3,1),
  corners              NUMERIC(3,1),
  predicted_psa_grade  TEXT,                      -- '9', '10', '9.5'
  predicted_cgc_grade  TEXT,
  regrade_target       TEXT NOT NULL,             -- 'psa', 'cgc', 'both', 'hold', 'sell_raw'
  rationale            TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TYPE grading_company AS ENUM ('psa', 'cgc', 'bgs', 'sgc');

-- A submission batch (one or many cards sent together)
CREATE TABLE grading_submissions (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id          UUID NOT NULL REFERENCES purchases(id),
  company              grading_company NOT NULL,
  submitted_at         DATE NOT NULL,
  service_level        TEXT NOT NULL,             -- 'economy', 'regular', 'express', 'walkthrough'
  submission_fee_cents INTEGER NOT NULL CHECK (submission_fee_cents >= 0),
  shipping_to_cents    INTEGER NOT NULL DEFAULT 0,
  tracking_number      TEXT,
  estimated_return     DATE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Result from a submission
CREATE TABLE grading_results (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id        UUID NOT NULL REFERENCES grading_submissions(id),
  received_at          DATE NOT NULL,
  grade                TEXT NOT NULL,             -- '10', '9', '9.5', 'AUTH'
  cert_number          TEXT,
  pop_at_receipt       INTEGER,                   -- snapshot of pop count at time of return
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sale of a graded result
CREATE TABLE sales (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  result_id            UUID NOT NULL REFERENCES grading_results(id),
  sold_at              DATE NOT NULL,
  platform             TEXT NOT NULL,
  sale_price_cents     INTEGER NOT NULL CHECK (sale_price_cents > 0),
  platform_fee_cents   INTEGER NOT NULL DEFAULT 0,
  shipping_cost_cents  INTEGER NOT NULL DEFAULT 0,
  buyer                TEXT,
  listing_url          TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## P&L Calculation

Net profit per purchase:

```
net_profit = sale_price
           - platform_fees
           - shipping_out
           - submission_fee
           - shipping_to_grader
           - purchase_price
```

Returned as a view `venture_pnl` joining purchases → submissions → results → sales.

## Market Context Queries

At report time, query `market-tracker-backend` (or its Postgres directly) to join market data:

```sql
-- PSA 9, PSA 10, CGC 10 market prices on the week of purchase
SELECT g.grade, g.company, g.market_price_cents, g.pop_count, g.pop_total
FROM graded_snapshots_weekly g
WHERE g.card_id = $market_tracker_card_id
  AND g.week_start_date = date_trunc('week', $purchased_at)
  AND g.grade IN ('9', '10')
ORDER BY g.company, g.grade;
```

The report CLI does this join at runtime rather than at purchase time.

## CLI Commands (v1)

| Command | Description |
|---|---|
| `add purchase` | Record a card purchase |
| `add analysis` | Record pre-grading analysis for a purchase |
| `add submission` | Record a grading submission |
| `add result` | Record the returned grade |
| `add sale` | Record a sale |
| `list purchases` | Show open positions (purchased but not yet sold) |
| `list results` | Show grading results with predicted vs actual grades |
| `report pnl` | P&L summary per purchase, with market context from MT |
| `report accuracy` | Predicted vs actual grade accuracy over time |
| `report signals` | Which open positions now have a watchlist signal |

## Database

PostgreSQL on Proxmox homelab. New database `graded_tracker` on the `market-tracker` Proxmox instance (192.168.86.182), separate DB from `market_tracker` but same server.

## Future (v2)

- REST API wrapping the CLI data model
- Hugo dashboard: open positions, P&L chart, grade accuracy stats
- Integration with `market-tracker` watchlist — clicking a signal opens "add purchase" flow
- Automated market context snapshot at purchase time (webhook or cron from market-tracker)
