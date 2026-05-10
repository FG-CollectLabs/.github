# FG-CollectLabs

Data collection and analysis tools for the TCG ecosystem — v2 of the
[FutureGadgetCollections](https://github.com/FutureGadgetCollections) toolkit.

## What this org is

FG-CollectLabs is the lab. It's where pricing, inventory, sell-through, and
market-signal pipelines live for trading card games (Magic, Pokémon, One
Piece, and whatever else is worth tracking). The goal is to turn noisy,
fragmented marketplace data into clean metrics that can drive decisions —
either directly (buy / hold / sell) or by feeding into an LLM that reasons
about timing.

This is a rebuild, not a fork. The original org grew organically and
collected a lot of single-purpose repos. v2 is opinionated:

- **Shared data shapes.** Every analyzer reads from and writes to the same
  schemas, so cross-product comparisons are cheap.
- **Sources are pluggable.** TCGPlayer, eBay, Crystal Commerce, retailer
  inventories — each one is a thin adapter. Swappable, mockable, testable.
- **Metrics over EV.** Expected-value-of-pack calculators already exist
  everywhere. The interesting questions are about *timing*: when does
  sealed go up, by how much, and what signals appear first?

## Sister orgs

- **[FG-CollectShop](https://github.com/FG-CollectShop)** — storefront and
  inventory management. Consumes signals and pricing from CollectLabs;
  exposes the public-facing store and the internal admin SPA.
- **[FutureGadgetCollections](https://github.com/FutureGadgetCollections)** —
  the v1 org. Repos are being audited and selectively migrated; expect
  nothing here to depend on it long-term.

## Repos

| Repo | Status | Purpose |
| --- | --- | --- |
| [`.github`](https://github.com/FG-CollectLabs/.github) | live | org profile and project planning docs |
| [`ws-set-analysis`](https://github.com/FG-CollectLabs/ws-set-analysis) | live | Weiss Schwarz booster investment analysis blog + Claude agent — [fg-collectlabs.github.io/ws-set-analysis](https://fg-collectlabs.github.io/ws-set-analysis/) |
| [`market-tracker-backend`](https://github.com/FG-CollectLabs/market-tracker-backend) | active | Go API + PostgreSQL + BigQuery pipeline for TCG market price tracking |
| [`card-identifier-backend`](https://github.com/FG-CollectLabs/card-identifier-backend) | active | Go API for card identification via pHash + OCR; metadata and pricing microservice |
| [`card-identifier-frontend`](https://github.com/FG-CollectLabs/card-identifier-frontend) | active | Vite/TS frontend for the card identifier |
| [`ev-calculator`](https://github.com/FG-CollectLabs/ev-calculator) | active | Go service: sealed product EV calculator, pulls live prices from market-tracker |
| [`sellthrough-analyzer`](https://github.com/FG-CollectLabs/sellthrough-analyzer) | scaffolding | sealed-box sell-through, depth, and price-move prediction signals |
| [`slab-cracker-frontend`](https://github.com/FG-CollectLabs/slab-cracker-frontend) | scaffolding | card-centering measurement web app (Vite + TypeScript); v2 of `slab-cracker` |
| [`slab-cracker-extension`](https://github.com/FG-CollectLabs/slab-cracker-extension) | scaffolding | Chrome MV3 extension: right-click capture, region capture, PSA/CGC cert auto-fetch |

## Conventions

- Python for data work, TypeScript for any UI.
- Each analyzer ships with a documented metric catalog — what we
  measure, how we measure it, what it's supposed to predict.
- Raw scrapes are immutable; derived metrics are recomputed from raw.
- Anything that hits a paid or rate-limited API is cached aggressively
  and never run by accident.
