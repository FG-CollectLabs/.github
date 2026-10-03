# Graded Tracker — Architecture

**Status:** Phase 1 built 2026-09-30 (not yet deployed; see TODO.md). Supersedes the price-tracking parts of
[`graded-market-watch`](../graded-market-watch/ARCHITECTURE.md) and Phase 1–2 of
[`auction-arb`](../auction-arb/ARCHITECTURE.md). The flood/dump detection in
`auction-arb` is kept as this project's Phase 3 in reshaped form (see §7).

## 1. Goal

Buy graded Pokémon cards cheaply at auction (Fanatics Collect first, obscure
auction sites later) and resell them elsewhere. To bid low with confidence we need,
for a hand-curated set of cards:

1. What each card is worth at each grade, from **several independent sources**,
   each showing **when it was last updated**.
2. **Every individual sale** on eBay and Fanatics, with its date, so we can see
   the spread of prices and **how many copies sell per week**.
3. Eventually, **supply dumps**: weeks where far more copies are for sale than the
   market normally absorbs, so the clearing price has to collapse.

## 2. Where it lives

No new repos. Same split as today:

| Repo | Adds |
|---|---|
| `market-tracker-backend` (Go) | migration, tracking rules + sync, sales/supply tables, API, **MCP server** (`cmd/mcp`) |
| `sellthrough-analyzer` (Python) | PriceCharting Pristine + reverse-holo fixes; later eBay graded-sold scrape |
| `market-tracker-frontend` (React) | "Tracked Cards" page |

## 3. Which cards are tracked

Rules in a checked-in config file, `market-tracker-backend/internal/tracking/tracking.yaml`
(embedded into the binaries; `sync-tracked -config <file>` overrides it). To change the
lists, edit the file; the sync job re-applies the rules.

```yaml
sets: [me1]                       # start with Mega Evolution; add sets here

# Every card at these rarities is tracked (base finish).
track_rarities:
  - Illustration Rare
  - Ultra Rare
  - Special Illustration Rare
  - Mega Hyper Rare
  - Hyper Rare

# Below those rarities, a card is tracked only if it matches a list,
# and only in the listed finish.
lower_rarity:
  finishes: [rh]                  # reverse holo only
  pokemon:                        # whole-word match on card name
    [charizard, pikachu, umbreon, gengar, mew, mewtwo, rayquaza, lugia, eevee, sylveon]
  artists:                        # case-insensitive match on illustrator
    [yuka morii, mitsuhiro arita, kagemaru himeno, tomokazu komiya, atsuko nishida,
     akira egawa, naoki saito, sowsow, kawayoo, shinji kanda]

grades: [raw, psa-9, psa-10, cgc-10, cgc-10-pristine]
```

The sync writes `tracked_cards`, one row per card with a `reason` column
(`rarity:illustration rare`, `artist:yuka morii`, `pokemon:charizard`, `manual`).
**Manual overrides win**: `pinned` rows are never removed by the sync and
`excluded` rows are never added back.

**ME1 under these rules** (verified against TCGdex 2026-09-30): 56 cards at
IR/UR/SIR/MHR (#133–188) + 8 reverse-holo artist matches (#012, 037, 042, 049,
052, 068, 082, 085) = **64 tracked rows**. No top-10 Pokémon appear below IR in ME1.

### Prerequisite: catalog enrichment

Every ME1 card is currently stored as `rarity = 'Unknown'`, with no illustrator and
no reverse-holo rows. Add `cmd/enrich-pokemon` to pull rarity, illustrator and
variants from **TCGdex** (`api.tcgdex.net/v2/en/cards/me01-NNN`). Use TCGdex rather
than pokemontcg.io, which returned 502s during planning.
- `cards.rarity` ← TCGdex rarity, normalized to title case (`Illustration Rare`).
- `cards.details.artist` ← illustrator.
- Reverse-holo rows: `display_key = pokemon-me1-052-rh`, `finish = 'rh'`,
  created only where TCGdex says the variant exists.

## 4. The price columns

One row per tracked card, one column group per source. **Every cell shows its own
as-of date**, and a cell older than its source's expected cadence is flagged stale.

| PriceCharting (weekly index) | eBay sold | Fanatics sold |
|---|---|---|
| Raw, PSA 9, PSA 10, CGC 10, CGC 10 Pristine | per grade: median, min, # sold last 7d / 30d, last sale date | per grade: median **all-in**, min, # sold per week, last sale date |

**Grade key.** Grades are text keys (`raw`, `psa-9`, `psa-10`, `cgc-10`,
`cgc-10-pristine`), never numbers, so CGC Pristine 10 and Gem Mint 10 never merge.
Map onto the existing `graded_snapshots_weekly (company, grade)` as `cgc`/`10` and
`cgc`/`Pristine 10`.

**Buyer's premium.** A Fanatics hammer price is not what you pay. Store `hammer`,
`buyers_premium_pct` and `all_in` separately. Fanatics columns show all-in, and
eBay columns show what the buyer paid (price plus shipping).

## 5. Schema (migration 0015)

The repo skips 0012, and prod already has version 14 recorded (lot-scout was applied as 0014 before being renamed 0013), so this is 0015.

```sql
CREATE TABLE tracked_cards (
  card_id     UUID PRIMARY KEY REFERENCES cards(id) ON DELETE CASCADE,
  reason      TEXT NOT NULL,              -- 'rarity:ultra rare', 'artist:yuka morii', 'manual'
  pinned      BOOLEAN NOT NULL DEFAULT false,
  excluded    BOOLEAN NOT NULL DEFAULT false,
  added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  note        TEXT
);

-- One row per individual sale. eBay and Fanatics (and later other houses).
CREATE TABLE card_sales (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id             UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  grade_key           TEXT NOT NULL,        -- 'psa-10', 'cgc-10-pristine', 'raw'
  source              TEXT NOT NULL,        -- 'ebay', 'fanatics', ...
  sold_at             TIMESTAMPTZ NOT NULL,
  price_cents         INTEGER NOT NULL,     -- eBay sale price / Fanatics hammer
  buyers_premium_pct  NUMERIC(5,2),         -- Fanatics
  shipping_cents      INTEGER,
  all_in_cents        INTEGER NOT NULL,     -- what the buyer actually paid
  sale_type           TEXT,                 -- 'auction', 'bin', 'best_offer'
  external_id         TEXT,                 -- eBay item id / Fanatics lot id
  cert_number         TEXT,
  url                 TEXT,
  title_raw           TEXT,
  entry_method        TEXT NOT NULL,        -- 'manual_mcp', 'scraper'
  recorded_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (source, external_id)
);
CREATE INDEX ON card_sales (card_id, grade_key, source, sold_at DESC);

-- "N copies of this card+grade are up for sale right now." Feeds dump detection.
CREATE TABLE card_supply_snapshots (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id       UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  grade_key     TEXT NOT NULL,
  source        TEXT NOT NULL,
  observed_at   TIMESTAMPTZ NOT NULL,
  active_count  INTEGER NOT NULL,
  closes_at     TIMESTAMPTZ,                -- Fanatics weekly close, if known
  url           TEXT,                       -- the search you counted from
  entry_method  TEXT NOT NULL,
  recorded_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Weekly sold counts per card+grade+source (Monday-start weeks).
CREATE VIEW card_sales_weekly AS
SELECT card_id, grade_key, source,
       date_trunc('week', sold_at)::date AS week_start_date,
       count(*)                          AS sold_count,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY all_in_cents) AS median_all_in_cents,
       min(all_in_cents) AS min_all_in_cents,
       max(all_in_cents) AS max_all_in_cents
FROM card_sales GROUP BY 1,2,3,4;

-- Every ingest run, automated or manual, so staleness is visible.
CREATE TABLE ingest_runs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source       TEXT NOT NULL,             -- 'pricecharting', 'ebay', 'fanatics'
  job          TEXT NOT NULL,             -- 'console-prices', 'mcp:record_sales', ...
  scope        TEXT,                      -- set code or display_key
  started_at   TIMESTAMPTZ NOT NULL,
  finished_at  TIMESTAMPTZ,
  status       TEXT NOT NULL,             -- 'running', 'succeeded', 'failed'
  rows_written INTEGER,
  error        TEXT
);
```

Without `external_id` there is no unique index: several copies really can close at the
same price on the same night. Instead the API skips a sale that matches an existing
one's card, grade, source, day and price as `possible_duplicate`, unless the caller sets
`allow_possible_duplicates`. As built, `card_sales` also has `note`, and `sale_type` is
constrained to `auction` / `bin` / `best_offer`.

## 6. MCP server (manual entry)

`market-tracker-backend/cmd/mcp`: a stdio MCP server in Go
(`github.com/modelcontextprotocol/go-sdk`), run locally from Claude Code. It writes
**through the backend admin API** (bearer token), never straight to Postgres, so
there is a single write path and it works from any machine.

Workflow: you review Fanatics/eBay solds by hand and tell the agent what you saw
("PSA 10 Mega Gardevoir SIR 178, Fanatics weekly, sold 9/28 for $410, 20% BP").
The agent resolves the card, shows its interpretation, and records it.

| Tool | Purpose |
|---|---|
| `find_card(query, set?)` | Resolve "gardevoir sir me1" → `pokemon-me1-178`. Tracked cards ranked first. |
| `list_tracked(set?)` | The tracked list with reasons. |
| `get_card(display_key)` | All price columns + as-of dates + recent sales, so the agent can sanity-check before writing. |
| `record_sales(display_key, grade_key, source, sales[])` | Each sale: `sold_at`, `price`, optional `buyers_premium_pct`, `shipping`, `sale_type`, `external_id`, `url`, `title`. Returns inserted vs duplicate. |
| `record_supply(display_key, grade_key, source, active_count, observed_at, closes_at?, url?)` | "40 copies of CGC 10 Pristine up this week." |
| `delete_sale(id)` | Undo a bad entry. |
| `track_card(display_key, pin \| exclude, note?)` | Manual overrides. |

Guardrails:
- `grade_key` is an enum, so the agent can't invent `cgc-10-perfect`.
- Fanatics sales require `buyers_premium_pct`, with the current rate as the default.
- Writes are rejected when `sold_at` is in the future, before 1996, or more than 60 days
  before the set's release date (TCGdex fills `sets.release_date`).
- Every call records an `ingest_runs` row with `job = 'mcp:<tool>'`.

## 7. Dump detection (Phase 3)

The question is whether this week's supply is more than the market absorbs:

```
typical_weekly_sold = median(sold_count over trailing 8 weeks, per card+grade+source)
absorption_ratio    = active_count_this_week / max(typical_weekly_sold, 1)
```

Flag when `absorption_ratio >= 3` **and** `active_count >= 10` (both tunable). The
floor matters: going from 1 copy to 3 is not a dump. Supply is also counted across
grade tiers, since Pristine and Gem Mint 10 compete for the same bidders (see the
`competing_supply` idea in `auction-arb`). For the absorption ratio to mean
anything, there need to be roughly 6–8 weeks of weekly sold counts first, so
**manual entry should start as soon as Phase 1 ships**.

A dump is only worth buying into if the discount is temporary. The gem-rate
break-even from `auction-arb` §4 is still how to tell a temporary discount from a
real repricing.

## 8. Cadence

| Source | How | When |
|---|---|---|
| PriceCharting | `console-prices` + per-card pages for CGC 10 / Pristine | weekly, Mon |
| eBay sold | manual via MCP now; automated graded scrape in Phase 2 | weekly |
| Fanatics sold + supply | manual via MCP | after the weekly close (Sun/Mon night) |
| Tracking sync | `cmd/sync-tracked` | after enrichment, and on config change |

## 9. Known issues this fixes along the way

- PriceCharting per-card scraper drops `CGC 10 Pristine` on purpose
  (`sellthrough-analyzer/src/sellthrough/graded/pricecharting.py:29-35`).
- PriceCharting reverse-holo rows collapse into the base card:
  `_number_from_slug` turns `helioptile-reverse-holo-52` into `052`.
- The "raw" price join takes the newest `card_snapshots_weekly` row from **any**
  source (`internal/graded/handler.go`, `queries/graded.sql`). Make the source
  explicit per column.
- The weekly cron has never successfully refreshed graded data. The worker at
  `127.0.0.1:8001` isn't running on `.199`, and the runner has no SSH key.
  **Manual MCP entry doesn't depend on either**; automated PriceCharting does.
