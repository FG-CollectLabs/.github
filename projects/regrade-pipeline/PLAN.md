# Regrade Pipeline — Umbrella Plan

End-to-end workflow for evaluating graded card buys, executing regrade ventures, and
building a historical dataset that improves future buy decisions. This plan spans
multiple existing repos rather than introducing a new one.

## Scope

**This pipeline is Pokemon-only.** MTG ventures in this stack are a separate workflow —
breaking sealed boxes into singles, priced via market-tracker-backend's existing raw +
EV calculator path. The grading/regrade decision flow described here applies only to
Pokemon cards because that's where the PSA 9 → PSA 10 regrade arbitrage lives at scale.

**Mobile-first UI.** The frontend (`graded-lister`) is designed for phone use — most
reviews happen at card shows or while glancing at eBay listings on the go. Desktop
remains supported but is not the primary form factor.

**OAuth gating.** Firebase Google sign-in with email allowlist
(`nguye208@gmail.com`) — same pattern as the rest of `graded-lister`. Tool is
private to me; later commercialization handled per-user out of band.

---

## The Workflow (target state)

```
                  ┌──────────────────────────────────────────────────────────┐
                  │  Weekly background ingest (market-tracker-backend)       │
                  │  • Raw prices    • PSA 9 / 10 prices    • Gem rates      │
                  │  • CGC 10 prices • Pop totals (PSA & CGC)                │
                  └──────────────────────────────────────────────────────────┘
                                              │
                                              ▼
   ┌──────────────────────────────────────────────────────────────────────────┐
   │  Decision surface (graded-lister UI)                                      │
   │  Cert lookup → see card + cert info + signals:                            │
   │    – Current PSA 9 / PSA 10 / CGC 10 market price                         │
   │    – Gem rate (PSA & CGC)                                                 │
   │    – Spread vs grading cost (regrade EV)                                  │
   │    – Historical misgrade rate for this card  ← NEW                        │
   │  Action: Buy / Pass / Watch                                               │
   └──────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
   ┌──────────────────────────────────────────────────────────────────────────┐
   │  Visual review (graded-lister UI + GRT API)            ← NEW             │
   │  Score centering / surface / edges / corners                              │
   │  Classify: "Legit 9" | "Looks like 10" | "Damaged 9" | "Other"            │
   │  Saves to GRT regardless of buy decision — builds the sample              │
   └──────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
   ┌──────────────────────────────────────────────────────────────────────────┐
   │  Ownership & P&L (graded-regrade-tracker)                                 │
   │  Record purchase → submission → result → sale                             │
   │  Track predicted-vs-actual grade accuracy over time                       │
   └──────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
   ┌──────────────────────────────────────────────────────────────────────────┐
   │  Feedback loop                                                            │
   │  Aggregate visual review data → "for card X PSA 9, N reviews,             │
   │  X% looked like a 10, your regrade success rate Y%" → improves            │
   │  the decision surface for the next buy                                    │
   └──────────────────────────────────────────────────────────────────────────┘
```

---

## Current State (as of 2026-05-23)

### ✓ Already built

| Component | Where |
|---|---|
| `graded_snapshots_weekly` schema with `pop_total`, `data_source`, `pop_higher` | `market-tracker-backend` migration 0004 + 0008 |
| `graded_gem_rates` view (computes gem rate per (card, company, grade=10) row) | migration 0008 |
| `graded_watchlist` table + `graded_signal` enum | migration 0008 |
| Weekly ingest scripts populating raw, PSA 9, PSA 10, CGC 10 prices + gem rates | User-confirmed running |
| PSA cert lookup with images → eBay CSV | `graded-lister` (just built) |
| Public homelab API surface pattern (CF tunnel + LXC + Postgres) | `slab-cracker`, `market-tracker`, `ev-calculator` patterns |

### ✗ Missing (the gap)

| Component | Why it's needed |
|---|---|
| Signal computation (`undervalued_10`, `regrade_candidate_9`) | Schema exists but `last_signal` column is never updated |
| `/v1/cards/:id/gem-rate` and `/v1/watchlist/graded` API endpoints | Frontends can't surface signals without these |
| `graded-regrade-tracker` repo (the whole P&L tracker) | Need a place to record purchases, submissions, results |
| **Visual Review Queue** (new concept) | The systematic dataset for "does this PSA 9 look like a 10?" |
| Decision Surface in `graded-lister` | Where all signals come together at buy-time |
| Cert-number → card-id resolution | A PSA cert returns subject/set strings; market-tracker uses UUID cards |

---

## The New Concept: Visual Review Queue

The piece that bridges everything. Users (you) systematically review cards seen in
the wild — your own purchases, but also other people's listings — and record an
opinion on whether the grade looks justified. Over time this builds a per-card
dataset that answers: *"when I see a PSA 9 of card X, what's the prior probability
that it visually looks like a 10?"*

### Data model

Lives in `graded_tracker` (the GRT database), table `review_observations`:

```sql
CREATE TYPE review_classification AS ENUM (
    'legit',          -- grade matches what I see
    'looks_higher',   -- looks like it should grade higher
    'looks_lower',    -- looks like it should grade lower
    'unsure'
);

CREATE TABLE review_observations (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- What was reviewed
    market_tracker_card_id UUID,                   -- soft reference to MT cards table; nullable for unmapped cards
    game                   TEXT NOT NULL DEFAULT 'pokemon',  -- this pipeline is pokemon-only for now
    set_code               TEXT NOT NULL,          -- PSA's VarietySet string, normalized if MT knows it
    card_number            TEXT,
    card_name              TEXT NOT NULL,

    -- The cert under review (optional — sometimes you review a raw card or photo)
    company                grading_company,        -- 'psa', 'cgc', etc; null = raw card
    grade                  TEXT,                   -- '9', '10', etc; null = raw
    cert_number            TEXT,                   -- PSA cert # if applicable; unique nullable

    -- Image refs (already uploaded to GCS by graded-lister-backend)
    front_image_url        TEXT,
    back_image_url         TEXT,

    -- The scoring
    centering              NUMERIC(3,1) CHECK (centering BETWEEN 0 AND 10),
    surface                NUMERIC(3,1) CHECK (surface   BETWEEN 0 AND 10),
    edges                  NUMERIC(3,1) CHECK (edges     BETWEEN 0 AND 10),
    corners                NUMERIC(3,1) CHECK (corners   BETWEEN 0 AND 10),
    predicted_grade        TEXT,                   -- my predicted grade if regraded
    classification         review_classification NOT NULL,
    confidence             SMALLINT CHECK (confidence BETWEEN 1 AND 5),

    -- Context
    notes                  TEXT,
    listing_url            TEXT,                   -- where you saw it (eBay, etc)
    seen_price_cents       INTEGER,                -- asking price at time of review
    reviewed_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewer               TEXT NOT NULL DEFAULT 'self',

    -- Was this purchased? If so link to GRT purchase
    purchase_id            UUID REFERENCES purchases(id),

    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Each cert can only be reviewed once per session (re-review uses upsert by cert+date)
    UNIQUE (cert_number, reviewer, DATE(reviewed_at))
);

CREATE INDEX idx_review_card_grade ON review_observations (market_tracker_card_id, company, grade);
CREATE INDEX idx_review_cert ON review_observations (cert_number) WHERE cert_number IS NOT NULL;
```

### Aggregation query (the killer feature)

For a given card + grade, what does the historical visual review data look like?

```sql
-- "How often do PSA 9s of this card look like they should be 10s?"
SELECT
    COUNT(*) FILTER (WHERE classification = 'legit')        AS legit_count,
    COUNT(*) FILTER (WHERE classification = 'looks_higher') AS looks_higher_count,
    COUNT(*) FILTER (WHERE classification = 'looks_lower')  AS looks_lower_count,
    COUNT(*) AS total_reviews,
    ROUND(
        COUNT(*) FILTER (WHERE classification = 'looks_higher')::numeric
        / NULLIF(COUNT(*), 0) * 100, 1
    ) AS misgrade_rate_pct,
    AVG(centering) AS avg_centering,
    AVG(surface)   AS avg_surface,
    AVG(edges)     AS avg_edges,
    AVG(corners)   AS avg_corners
FROM review_observations
WHERE market_tracker_card_id = $1
  AND company = $2
  AND grade   = $3;
```

A high `misgrade_rate_pct` on PSA 9s for a given card is the strongest signal that
the next PSA 9 you see for that card is also likely undergraded — combined with
gem rate (how hard it is to gem) and price spread (PSA 10 vs PSA 9), this becomes
the regrade buy thesis.

### Where the UI lives

Inside `graded-lister`, **mobile-first**. After a cert lookup, the Decision view
becomes the primary screen — single-column layout, fat tap targets, slider inputs
sized for thumb interaction. After a cert lookup, a new "Review" tab/button appears:

```
┌─ Review for Regrade ──────────────────────────────────────┐
│                                                            │
│   [Front image]   [Back image]                             │
│                                                            │
│   Centering   [9.0]  ←─────●──────→                        │
│   Surface     [9.5]  ←──────●─────→                        │
│   Edges       [9.5]  ←──────●─────→                        │
│   Corners     [8.5]  ←────●───────→                        │
│                                                            │
│   Classification:  ○ Legit  ● Looks higher  ○ Lower  ○ ?   │
│   Confidence:      ○─○─○─●─○  (4/5)                        │
│                                                            │
│   Notes: _____________________________________             │
│                                                            │
│   Where seen: [ eBay listing URL ___________ ]             │
│   Asking price: $ [___]                                    │
│                                                            │
│   [Save Review]                                            │
└────────────────────────────────────────────────────────────┘
```

Reviews are saved over HTTP to a new endpoint on `graded-lister-backend`, which
inserts into `graded_tracker.review_observations`. This means GRT needs a slim
HTTP API even in v1, not the CLI-only design from the original plan.

---

## Architectural Decisions

### 1. graded-lister-backend grows, GRT becomes API-first

Original GRT plan was CLI + Postgres only, no HTTP server. Reality is the
visual review queue is most useful from the `graded-lister` frontend. So GRT
gets an HTTP API up front. The backend can be a separate `graded-tracker-api`
service or a new set of handlers in `graded-lister-backend`.

**Decision:** Put the API in `graded-lister-backend` to keep deployment simple.
The `graded_tracker` Postgres database is the canonical store; the backend
gains `internal/tracker/` package alongside `internal/psa/`.

### 2. Cert-number → card-id mapping

PSA returns `Subject="Rayquaza VMAX"`, `VarietySet="Evolving Skies"`,
`CardNumber="218/203"`. Market-tracker uses UUID `cards.id`. Resolution path leverages
existing MT catalog structure:

1. **Set match.** PSA `VarietySet` → `sets.name` using pg_trgm similarity (e.g.,
   `similarity(sets.name, 'SWSH Black Star Promos') > 0.5`), filtered to `game='pokemon'`
2. **Card match.** Within the matched set, PSA `Subject` + `CardNumber` → `cards.name`
   + `cards.number` (also pg_trgm on name for variant naming differences)
3. **Promo handling.** When PSA `VarietySet` contains "Promo" / "Black Star Promos",
   prefer cards with `finish='promo'` in the result set. Promos are first-class in
   MT — no special schema needed
4. **Cache.** Once resolved, write a row to `cert_card_map (cert_number, card_id,
   resolved_at, confidence_score)` so re-lookups are O(1)
5. **Ambiguous match.** If multiple cards score above the confidence threshold,
   return the candidate list to the UI and let the user pick. The pick is then
   cached for that cert
6. **No match.** Store the review with `market_tracker_card_id = NULL` and fully
   populated `card_name` / `set_code` / `card_number` strings. A nightly resolver
   job retries unmapped reviews so they get linked once MT learns about the card

Note: the running ingest script already populates `card_external_ids` rows with
`system='pricecharting'`, so PSA cert lookups for cards MT knows about will succeed.
The misses are cards MT hasn't ingested yet (typically very new sets or obscure
promos).

### 3. Signal computation lives where the data lives

`cmd/compute-graded-signals` runs in `market-tracker-backend` (same DB as the
gem rate + price data). Output goes into `graded_watchlist.last_signal`. The
frontend reads via `GET /v1/watchlist/graded` and `GET /v1/cards/:id/signals`.

### 4. Misgrade-rate as a signal lives where reviews live

Visual review aggregations are computed in `graded_tracker` DB. A new endpoint
on `graded-lister-backend` (`GET /v1/reviews/aggregate?card_id=X&company=Y&grade=Z`)
joins the answer into the decision surface. We do not denormalize this into
market-tracker — keeps the boundary clean.

---

## Build Sequence

Each phase produces something usable end-to-end before moving on.

### Phase 1 — Signal computation + API surfacing (market-tracker-backend)

Goal: surface gem rate and basic regrade signals via API. No new schema needed,
the data is already being ingested.

- [ ] `cmd/compute-graded-signals` — computes `undervalued_10` and `regrade_candidate_9` per watchlist entry
  - Thresholds via env vars: `SIGNAL_GEM_RATE_MAX_UNDERVALUED`, `SIGNAL_REGRADE_MIN_PROFIT_CENTS`
  - Runs after `ingest-prices` in the weekly job
- [ ] `GET /v1/cards/:id/graded` — return all graded snapshots for a card (latest per company/grade)
- [ ] `GET /v1/cards/:id/gem-rate` — convenience endpoint for PSA + CGC gem rate
- [ ] `GET /v1/cards/:id/signals` — combined view: prices + gem rates + computed regrade EV
- [ ] `GET /v1/watchlist/graded`, `POST /v1/watchlist/graded`, `DELETE /v1/watchlist/graded/:id`

**Done when:** you can hit `https://market.futuregadgetlabs.com/v1/cards/{id}/signals` and get
back `{psa9_price, psa10_price, gem_rate_pct, regrade_ev_cents, signal}`.

### Phase 2 — GRT database + cert resolver

Goal: stand up the `graded_tracker` database with schema for purchases + visual reviews,
and build the cert-to-card resolver.

- [ ] Provision `graded_tracker` database on `192.168.86.182`
- [ ] Migration 0001: `tracked_cards`, `purchases`, grading_company enum
- [ ] Migration 0002: `pre_grading_analyses`, `grading_submissions`, `grading_results`, `sales`
- [ ] Migration 0003: `review_observations` (the new visual review table)
- [ ] Migration 0004: `cert_card_map` (cache: PSA cert # → card_id resolution)
- [ ] Migration 0005: `venture_pnl` view + review aggregation view
- [ ] sqlc queries for review CRUD + aggregation

**Done when:** you can manually insert a `review_observations` row via psql and run the
aggregation query against it.

### Phase 3 — graded-lister-backend gains tracker API

Goal: the frontend can write reviews and read aggregations.

- [ ] Add `internal/tracker/` package — Postgres pool, sqlc-generated queries
- [ ] Add `internal/resolver/` — PSA cert → market_tracker card_id with cache table
- [ ] `POST /v1/reviews` — insert a review_observation
- [ ] `GET /v1/reviews/cert/:cert` — fetch existing review for a cert (so UI can prefill on re-review)
- [ ] `GET /v1/reviews/aggregate?card_id=X&company=Y&grade=Z` — misgrade-rate stats
- [ ] `GET /v1/cards/resolve?subject=X&set=Y&number=Z` — calls MT API to find the card_id
- [ ] Update env: add `GRADED_TRACKER_DSN`, `MARKET_TRACKER_BASE_URL`

**Done when:** you can POST a review and GET it back, and aggregation returns counts.

### Phase 4 — Decision Surface in graded-lister UI (mobile-first)

Goal: when you look up a cert, you see all the signals on one screen — designed
for one-thumb phone use at a card show.

- [ ] New "Decision" view in `graded-lister` (between Lookup and Listing tabs)
- [ ] Single-column mobile layout, sliders sized ≥44px tap target, sticky bottom action bar
- [ ] Fetches in parallel: PSA cert data, `cards/resolve`, `cards/:id/signals`, `reviews/aggregate`
- [ ] Surface block: market prices, gem rate, regrade EV, historical misgrade rate
- [ ] Surface block: review form (saves to `POST /v1/reviews`)
- [ ] Surface block: action buttons "Buy" (links to GRT purchase entry), "Pass", "Watch" (adds to MT watchlist)
- [ ] Add `manifest.json` + Apple touch icon so it installs to home screen as a PWA
- [ ] Hide gem rate when `pop_total < 30` (common-card noise filter)

**Done when:** a cert lookup ends with a clear "this card has X% historical misgrade, Y regrade EV, recommend BUY/PASS" — readable and usable on an iPhone in portrait without zooming.

### Phase 5 — GRT purchase + result tracking (UI in graded-lister)

Goal: complete the buy → submit → result → sale → P&L loop with a UI, not CLI.

- [ ] New "Ventures" view in `graded-lister` — list of open purchases
- [ ] `POST /v1/purchases` — record a buy (with link back to the review observation if any)
- [ ] `POST /v1/purchases/:id/submissions` — record sending to PSA/CGC
- [ ] `POST /v1/submissions/:id/result` — record returned grade + cert
- [ ] `POST /v1/results/:id/sale` — record sale
- [ ] `GET /v1/reports/pnl` — venture P&L summary
- [ ] `GET /v1/reports/accuracy` — predicted vs actual grade accuracy

**Done when:** a full venture (buy → grade → sell) is recorded from the UI and P&L is computed.

### Phase 6 — Feedback loop polish

Goal: close the loop between predictions and results.

- [ ] When `add result` is called, find the matching review_observation by cert# and join: was the prediction right?
- [ ] Per-card accuracy view: "for set X, my predictions are 80% accurate"
- [ ] Recommend confidence weighting: if your past predictions for foils are weak, downweight foil reviews in the misgrade rate
- [ ] Export a "regrade thesis" report: list of cards where (misgrade_rate * (psa10_price - psa9_price - grading_fee)) > threshold

---

## Resolved Decisions

1. **Game scope.** Pokemon-only for the regrade pipeline. MTG stays in market-tracker
   for sealed→singles workflow and is out of scope here.

2. **UI form factor.** Mobile-first throughout. Phase 4 spec explicitly calls for
   single-column layout, large tap targets, sticky bottom action bar, and PWA install.

3. **Auth.** Firebase Google sign-in, email-allowlisted to `fglabs.contact@gmail.com`
   (already in place on `graded-lister`).

4. **Low pop_total filter.** Gem rate is hidden when `pop_total < 30` — those cards
   are typically commons with too little data to be meaningful signal.

5. **Review-vs-actual feedback.** When grading result comes back, join to the
   pre-purchase review observation by cert#. Surface prediction accuracy loudly in
   the accuracy report — this is the highest-value feedback loop.

## Resolved (continued)

6. **Promos in scope.** Pokemon promos are first-class targets — particularly
   SWSH Black Star Promos and SV Black Star Promos which have meaningful regrade
   spreads. MT's existing `cards.finish='promo'` value handles them with no
   schema changes.

7. **Catalog/pricing source.** PriceCharting via the running ingest script. MT's
   `card_external_ids` table is populated with `system='pricecharting'` mappings
   as cards are seen. The cert resolver leverages this.

8. **Backfill strategy.** A nightly `cmd/resolve-unmapped-reviews` job in
   `graded-lister-backend` re-runs the resolver against
   `review_observations WHERE market_tracker_card_id IS NULL` and links them as
   MT learns about new cards.

## Open Questions

None blocking Phase 1. Discovery items to handle as they come up:

- Confidence threshold tuning for the pg_trgm match (start at 0.5, adjust based
  on actual ambiguity rate)
- Whether to surface PriceCharting product ID in the UI when MT has it (useful
  for the user to double-check the mapping was correct)

---

## Phased Repo Touch List

| Repo | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|---|---|---|---|---|---|
| `market-tracker-backend` | ●●● new cmd + 5 endpoints | — | — | — | — |
| `graded-lister-backend` | — | — | ●●● new package + 6 endpoints | — | ●●● 5 endpoints |
| `graded-lister` (frontend) | — | — | — | ●●● new Decision view | ●● Ventures view |
| `graded_tracker` DB | — | ●●● 5 migrations | — | — | — |

---

## Memory updates after plan is approved

Once we start building, save:

- `project_regrade_pipeline.md` — top-level project memory pointing here
- Update `project_market_tracker_v2.md` — note graded layer + watchlist now active
- Update `project_graded_lister.md` — note tracker API integration
- Update `project_graded_regrade_tracker.md` — note API-first pivot (was CLI-only)

Mark this doc as the canonical sequence; sub-project planning docs become refinements.
