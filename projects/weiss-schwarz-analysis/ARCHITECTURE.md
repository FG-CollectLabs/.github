# Weiss Schwarz Set Analysis — Architecture

> **Status:** Draft v0.1 — pre-implementation
> **Codename:** `ws-set-analysis`
> **Goal:** A pseudo-blog + agent-driven system that produces investment analysis for Weiss Schwarz booster sets. Answers the core question: *should I preorder, or wait for a post-release dip?*

---

## North-star feature set

1. **IP Strength** — Score an IP using MyAnimeList (anime + manga rank, score, members) with Google Trends as fallback for unranked IPs.
2. **Historical EN Performance** — For every prior English printing of the IP, track preorder price, pull rates, high-rarity values, release date, and current price. Derive trend.
3. **JP Set Analysis** — For the current Japanese set, extract all card prices from Yuyutei. Exclude AGR/signed rarities (they never appear in EN). Compute slot EV.
4. **Competitive Meta** — Score competitive standing from weissteatime.com tournament results: field representation %, top-cut conversion rate, and trend across BCS/BSF/Worlds seasons. Produces a tier (`high` / `mid-high` / `mid` / `low` / `none`) and a narrative covering both the powercreep thesis (new prints strictly upgrade top-tier decks) and the missing-piece thesis (mid-tier sets may unlock viability with a future release).
5. **Recommendation** — Synthesize into a preorder signal: `strong-buy`, `buy`, `wait-for-dip`, or `pass`.
6. **Blog output** — Generate a Hugo markdown post. Posts carry a `stage` tag so the same set can be revisited at preorder → 30d → 90d → 1yr.

---

## System diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Analysis Agent (Claude Code / SDK agent, run locally on demand)         │
│                                                                           │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐    │
│  │ IP Strength      │  │ EN Historical     │  │ JP Set Analysis      │    │
│  │ sub-agent        │  │ sub-agent         │  │ sub-agent            │    │
│  └────────┬─────────┘  └────────┬──────────┘  └──────────┬───────────┘   │
│           │                     │                          │               │
│    mcp-jikan            mcp-ws-prices              mcp-yuyutei            │
│    (Jikan v4 API)       (TCGPlayer scrape)         (Yuyutei scrape)       │
│                                                                           │
│  ┌─────────────────────────────────────────┐                             │
│  │ Competitive Meta sub-agent              │                             │
│  └──────────────────┬──────────────────────┘                             │
│                     │                                                     │
│             mcp-weissteatime                                              │
│             (weissteatime.com tournament scraper)                        │
│                                 │                                          │
│                         seed-data/*.json                                   │
│                         (pull rates, preorder prices — manual V1)         │
│                                                                           │
│  ┌─────────────────────────────────────────┐                             │
│  │ Synthesis + Blog Post Generator         │                             │
│  │  → writes content/<set-slug>/index.md  │                             │
│  └─────────────────────────────────────────┘                             │
└──────────────────────────────────────────────────────────────────────────┘
                              │
                   Hugo static site build
                              │
                    GitHub Pages deployment
                              ▼
               https://fg-collectlabs.github.io/ws-set-analysis/
```

---

## Repos

| Repo | Role | Status |
|------|------|--------|
| `FG-CollectLabs/ws-set-analysis` | Hugo blog + agent scripts + MCP servers | NEW |

Single-repo for V1. If MCP servers grow, split to `ws-analysis-tools` later.

### Internal directory layout

```
ws-set-analysis/
├── blog/                          ← Hugo site root
│   ├── config.toml
│   ├── content/
│   │   └── sets/
│   │       └── rezero-vol3/
│   │           └── preorder.md   ← generated blog posts (one per set+stage)
│   ├── layouts/
│   │   └── sets/
│   │       └── single.html       ← set post template
│   ├── static/
│   └── themes/
│
├── agents/
│   ├── preorder/
│   │   ├── README.md             ← agent orchestration docs
│   │   ├── run.py                ← entry point: python run.py <set-config.json>
│   │   ├── ip_strength.py        ← MAL + Google Trends sub-agent
│   │   ├── en_historical.py      ← EN set history sub-agent
│   │   ├── jp_set_analysis.py    ← Yuyutei JP set sub-agent
│   │   ├── competitive_meta.py   ← tournament meta sub-agent (weissteatime)
│   │   ├── synthesis.py          ← recommendation engine
│   │   └── post_generator.py     ← generates Hugo markdown from structured data
│   └── sets/
│       └── rezero-vol3.json      ← set config: MAL IDs, EN set list, JP set IDs, etc.
│
├── mcp/
│   ├── jikan/                    ← MCP server: MyAnimeList via Jikan v4 API
│   │   ├── server.py
│   │   └── README.md
│   ├── yuyutei/                  ← MCP server: Yuyutei JP card prices (scraper)
│   │   ├── server.py
│   │   └── README.md
│   ├── ws-prices/                ← MCP server: EN card prices (TCGPlayer scraper)
│   │   ├── server.py
│   │   └── README.md
│   └── weissteatime/             ← MCP server: tournament meta from weissteatime.com
│       ├── server.py
│       └── README.md
│
├── seed-data/
│   ├── en-sets/
│   │   ├── rezero-vol1.json      ← preorder prices, pull rates, release dates (manual)
│   │   ├── rezero-vol2.json
│   │   ├── rezero-memory-snow.json
│   │   └── rezero-frozen-bond.json
│   └── jp-sets/
│       └── (populated by mcp-yuyutei scrapes, committed as cache)
│
├── CLAUDE.md                     ← repo-specific conventions
└── README.md
```

---

## MCP Servers

### `mcp-jikan` — MyAnimeList via Jikan v4

Jikan (https://jikan.moe) is an unofficial MAL REST API — no auth required.

**Tools exposed:**

| Tool | Input | Output |
|------|-------|--------|
| `get_anime` | `mal_id: int` | rank, score, members, favorites, popularity, status, episodes |
| `get_manga` | `mal_id: int` | rank, score, members, favorites, popularity, status, volumes |
| `search_anime` | `query: str` | top 5 matches with ID + score |
| `search_manga` | `query: str` | top 5 matches with ID + score |

**Implementation:** Python + `httpx`. Base URL: `https://api.jikan.moe/v4`. Rate limit: 3 req/s, 60 req/min — add 400ms sleep between calls.

### `mcp-yuyutei` — Japanese card prices

Yuyutei (https://yuyu-tei.jp) lists WS JP card prices. Requires HTML scraping with BeautifulSoup.

**Tools exposed:**

| Tool | Input | Output |
|------|-------|--------|
| `search_set` | `query: str` | list of matching sets with yuyutei set IDs |
| `get_set_cards` | `set_id: str` | all cards in a set with rarity, name, current buy price |
| `get_set_summary` | `set_id: str` | set-level aggregate: rarity breakdown, top 10 by price, computed slot EV |

**Rarity filter:** Exclude `AGR` rarity (autograph/signed) from EV calculations. These never appear in EN prints.

**Implementation:** Python + `requests` + `BeautifulSoup4`. Add caching layer: write scraped results to `seed-data/jp-sets/<set_id>.json` with a `cached_at` timestamp. Re-use cache if <24h old.

### `mcp-ws-prices` — English card prices

Scrapes TCGPlayer for EN WS card prices.

**Tools exposed:**

| Tool | Input | Output |
|------|-------|--------|
| `get_card_price` | `card_name: str, set_name: str` | market price, low price, high price |
| `get_set_summary` | `set_name: str` | top cards by price, SP/SSP average values |
| `get_box_price` | `set_name: str` | current sealed booster box market price |

**Implementation:** Python + `requests` or playwright if JS rendering required. Check if TCGPlayer has public endpoints first; scrape as fallback.

### `mcp-weissteatime` — Tournament meta from weissteatime.com

weissteatime.com is the community-authoritative source for EN WS competitive results. It covers Worlds, BCS (regional circuit), and BSF (store finals) with consistent event masterposts listing field representation % and top-cut placement by set code. WS is a non-rotating format — competitive demand compounds because new prints for top-tier IPs strictly upgrade existing decks (powercreep driver), and mid-tier sets may have future-release upside ("missing piece" thesis).

**Tools exposed:**

| Tool | Input | Output |
|------|-------|--------|
| `get_tournament_index()` | — | list of all tournament posts: title, event type (Worlds/BCS/BSF), date range, URL |
| `get_event_meta(url: str)` | post URL | per-set-code: field %, top-cut appearances, first-place count, event size |
| `get_set_competitive_history(set_codes: list[str])` | e.g. `["OSK", "RZ"]` | per season: field %, conversion rate, trend (rising/falling/stable), events covered |

**Competitive tier classification** (applied by `competitive_meta.py`, not the MCP server):

| Tier | Criteria |
|------|----------|
| `high` | ≥15% field in any major event, OR finalist/winner at Worlds, OR ≥10% average across 2+ seasons |
| `mid-high` | 8–15% field OR conversion rate ≥18% at ≥5% field across 2+ events |
| `mid` | 3–8% field with top-cut appearances; flag "missing piece" — a future release may unlock full viability |
| `low` | <3% field or only isolated results |
| `none` | No tournament presence found |

**Caching:** Write raw event JSON to `seed-data/competitive/<event-slug>.json` with `cached_at`. Re-use if <7d old (events don't change after posting).

**Implementation:** Python + `httpx` + `BeautifulSoup4`. The tournament category page at `weissteatime.com/category/deck-lists/tournament-decks/` lists all posts; each event post has per-set field stats.

---

## Analysis Agent

### Set config schema (`agents/sets/<set-slug>.json`)

```json
{
  "set_name": "Re:Zero Vol.3",
  "set_slug": "rezero-vol3",
  "ip_name": "Re:Zero",
  "mal_anime_id": 31240,
  "mal_manga_id": 74697,
  "language": "EN",
  "status": "preorder",
  "expected_release": "2026-Q3",
  "competitive_set_codes": ["RZ"],
  "en_historical_sets": [
    { "name": "Re:Zero Vol.1",      "slug": "rezero-vol1",       "seed": "seed-data/en-sets/rezero-vol1.json" },
    { "name": "Re:Zero Vol.2",      "slug": "rezero-vol2",       "seed": "seed-data/en-sets/rezero-vol2.json" },
    { "name": "Re:Zero Memory Snow","slug": "rezero-memory-snow", "seed": "seed-data/en-sets/rezero-memory-snow.json" },
    { "name": "Re:Zero Frozen Bond","slug": "rezero-frozen-bond", "seed": "seed-data/en-sets/rezero-frozen-bond.json" }
  ],
  "jp_equivalent_sets": [
    { "name": "Re:Zero Vol.1 (JP)", "yuyutei_id": null, "notes": "look up on yuyutei" },
    { "name": "Re:Zero Vol.2 (JP)", "yuyutei_id": null },
    { "name": "Re:Zero Memory Snow (JP)", "yuyutei_id": null },
    { "name": "Re:Zero Frozen Bond (JP)", "yuyutei_id": null },
    { "name": "Re:Zero Vol.3 (JP)",  "yuyutei_id": null, "is_current": true }
  ]
}
```

### Agent orchestration flow

```
run.py <set-slug>
  │
  ├── 1. Load set config from agents/sets/<slug>.json
  │
  ├── 2. IP Strength (ip_strength.py)
  │       ├── mcp-jikan: get_anime(mal_anime_id)
  │       ├── mcp-jikan: get_manga(mal_manga_id)
  │       ├── IF no rank: Google Trends (pytrends) for search volume
  │       └── Score: Strong (top 500 / >500k members) | Moderate | Niche
  │
  ├── 3. EN Historical Performance (en_historical.py)
  │       FOR EACH en_historical_set:
  │         ├── Load seed-data for preorder price, pull rates, release date
  │         ├── mcp-ws-prices: get_box_price(set_name) → current price
  │         ├── mcp-ws-prices: get_set_summary(set_name) → current high-rarity values
  │         └── Compute: price change %, time elapsed, peak-to-current delta
  │
  ├── 4. JP Set Analysis (jp_set_analysis.py)
  │       FOR EACH jp_equivalent_set:
  │         ├── mcp-yuyutei: search_set(name) → resolve yuyutei_id
  │         ├── mcp-yuyutei: get_set_summary(yuyutei_id)
  │         └── For current set: full card list + EV breakdown
  │
  ├── 4b. Competitive Meta (competitive_meta.py)
  │       ├── mcp-weissteatime: get_tournament_index() → list all event posts
  │       ├── FOR EACH event (cache hit preferred):
  │       │     mcp-weissteatime: get_event_meta(url) → per-set field % and top-cut
  │       ├── mcp-weissteatime: get_set_competitive_history(set_codes)
  │       ├── Classify tier: high / mid-high / mid / low / none
  │       ├── Detect trend: rising / falling / stable (YoY field % change)
  │       ├── Flag "missing piece" if tier=mid and conversion_rate >= 15%
  │       └── Produce: { tier, trend, field_pct_by_season, top_cut_count, missing_piece, narrative }
  │
  ├── 5. Synthesis (synthesis.py)
  │       ├── IP score (weighted: anime rank × 0.6 + manga × 0.4)
  │       ├── EN trend (did prior sets appreciate? or dip-and-recover?)
  │       ├── JP EV vs typical EN preorder price (~$85-100 for EN)
  │       ├── Competitive tier + modifier (from competitive_meta.py output)
  │       └── → recommendation: strong-buy | buy | wait-for-dip | pass
  │
  └── 6. Post Generator (post_generator.py)
          → writes blog/content/sets/<slug>/preorder.md
          (Hugo front matter + structured markdown)
```

### Recommendation logic (V1 heuristics — refine after first few sets)

**Base signal from IP strength + EN trend:**

| Condition | Signal |
|-----------|--------|
| IP rank < 500 on MAL anime + prior EN sets held or appreciated | `strong-buy` |
| IP rank 500-2000 + positive EN trend | `buy` |
| IP rank < 2000 but prior EN sets dipped >20% post release | `wait-for-dip` |
| IP rank > 2000 or niche + EN trend flat/negative | `pass` |
| JP EV significantly higher than expected EN preorder price | upgrade by one tier |

**Competitive meta modifier (applied after base signal):**

| Competitive tier | Modifier | Rationale |
|-----------------|----------|-----------|
| `high` (≥15% field or Worlds finalist) | **+1 tier** | New prints strictly upgrade the deck (non-rotating powercreep). Sustained tournament demand drives secondary market. |
| `mid-high` (8-15% field, strong conversion) | neutral | Solid meta presence without dominant share; holds value but no multiplier. |
| `mid` (3-8%, notable top-cut, rising trend) | neutral + flag **"missing piece"** | A future release synergizing with existing cards could unlock this deck; mid-tier buying now is low-risk with upside. |
| `mid` (3-8%, flat/falling trend) | neutral | Present but no near-term catalyst; no adjustment. |
| `low` / `none` | **−1 tier** | No competitive demand; secondary market relies entirely on casual collectors. |

These heuristics are V1 starting points. We tune them after running the first 3-4 analyses and comparing predictions to outcomes.

---

## Blog post structure (Hugo)

### Front matter

```yaml
---
title: "Re:Zero Vol.3 — Preorder Analysis"
date: 2026-05-10
set_name: "Re:Zero Vol.3"
set_slug: "rezero-vol3"
ip: "Re:Zero"
stage: "preorder"           # preorder | release | 30d | 90d | 1yr
recommendation: "buy"       # strong-buy | buy | wait-for-dip | pass
analyst: "claude-agent"
draft: false
---
```

### Sections

```markdown
## TL;DR
[one-paragraph recommendation summary]

## IP Strength
- Anime: MAL rank, score, member count, favorites
- Manga: same
- Assessment: Strong / Moderate / Niche

## Historical EN Performance
[table: set name | preorder $ | current $ | change % | time elapsed]
[pull rate table: rarity | rate | avg value]
[Pattern observed: sets dipped X% in first 30d, recovered to Y% of preorder over 12mo]

## Japanese Set Analysis (Re:Zero Vol.3)
[card table: rarity | count | avg price | notes]
[EV summary: expected pulls per box, gross EV, EV vs typical $90 EN preorder]
[Notable cards: top 5 highest-value pulls]

## Competitive Standing
[Tier badge: high / mid-high / mid / low / none]
[Season-by-season table: season | event type | field % | top-cut appearances | conversion rate]
[Trend summary: rising / stable / falling over last 2 seasons]
[Powercreep thesis if tier=high: "New prints for this IP strictly improve the existing deck archetype, sustaining tournament demand and secondary market prices."]
[Missing piece note if tier=mid + rising conversion: "This deck has shown strong conversion efficiency but limited field share — it may be missing one key card that a future release provides, making current cards a low-risk hold."]

## Recommendation: [BADGE]
[detailed reasoning]

## Data sources & methodology
[links to MAL, Yuyutei, TCGPlayer — dated snapshot]
```

---

## Seed data schema (`seed-data/en-sets/<slug>.json`)

```json
{
  "set_name": "Re:Zero Vol.1",
  "set_slug": "rezero-vol1",
  "release_date": "2018-07-27",
  "preorder_price_usd": 82.00,
  "pull_rates": [
    { "rarity": "SP",  "rate_per_box": 1.0,  "description": "1 guaranteed per box" },
    { "rarity": "SSP", "rate_per_box": 0.25, "description": "roughly 1 per 4 boxes" },
    { "rarity": "RRR", "rate_per_box": 8.0,  "description": "8 per box" }
  ],
  "competitive_standing": "moderate",
  "notes": "Launched alongside a crowded meta; see tournament results 2018-2020"
}
```

Current prices and rarity values are fetched live via MCP servers, not stored in seed data (they change).

---

## Data sources

| Source | URL | Access method | Notes |
|--------|-----|---------------|-------|
| MyAnimeList (via Jikan) | https://api.jikan.moe/v4 | REST API, no auth | 3 req/s rate limit |
| Yuyutei | https://yuyu-tei.jp/game_ws/sell/list.php | HTML scrape | JP WS prices |
| TCGPlayer | https://www.tcgplayer.com/search/weiss-schwarz | HTML scrape / public endpoints | EN prices |
| Bushiroad EN set pages | https://en.ws-tcg.com/products/ | HTML scrape | Official pull rate PDFs |
| heartofthecards.com | https://www.heartofthecards.com/code/cardlist.html | HTML scrape | EN/JP catalog fallback |
| weissteatime.com tournaments | https://weissteatime.com/category/deck-lists/tournament-decks/ | HTML scrape | EN competitive results: Worlds, BCS, BSF; field %, top-cut, conversion rates |
| Bushiroad EN events (fallback) | https://en.ws-tcg.com/events/ | HTML scrape | Official results; less aggregated than weissteatime |

---

## Key architectural decisions

See `DECISIONS.md` for full records.

1. **Single repo** for blog + agents + MCP servers in V1. Split if MCP servers become shareable. (WD-001)
2. **Python for MCP servers** — BeautifulSoup/httpx ecosystem fits scraping; agent orchestration in same language for simplicity. (WD-002)
3. **Hugo for blog** — matches existing tooling familiarity; GH Pages for hosting. (WD-003)
4. **Jikan (unofficial MAL API)** over direct MAL scraping — rate limits are manageable, API is stable enough. (WD-004)
5. **Manual seed data for V1** EN pull rates and preorder prices — scraping historical PDF pull rates is fragile; we input the first batch manually and automate later. (WD-005)
6. **Exclude AGR rarity from JP EV** — signed cards never appear in EN prints, would inflate EV unfairly. (WD-006)
7. **Stage-tagged posts** — same set gets multiple posts (`preorder`, `30d`, `90d`, `1yr`) so we can track our prediction accuracy. (WD-007)
8. **weissteatime.com for competitive meta** — community-authoritative source for EN Worlds/BCS/BSF results; captures field %, conversion rates, and multi-season trend needed for powercreep and missing-piece theses. (WD-010)

---

## Domain glossary

| Term | Meaning |
|------|---------|
| **IP** | Intellectual Property (anime/manga franchise — Re:Zero, SAO, etc.) |
| **EN set** | English-language WS booster release |
| **JP set** | Japanese-language WS booster release (usually precedes EN by 12-18 months) |
| **SP** | Special Parallel rarity — the top pull in most EN sets |
| **SSP** | Super Special Parallel — sometimes present; higher rarity than SP |
| **AGR** | Autograph rarity — signed cards; JP only, never reprinted in EN |
| **SEC** | Secret rarity — similar exclusion logic as AGR |
| **RRR** | Triple Rare — base foil; appears in EN, high-volume slot |
| **Box EV** | Expected Value of one booster box based on pull rates × card prices |
| **Stage** | Phase of the analysis lifecycle: `preorder`, `release`, `30d`, `90d`, `1yr` |
| **Preorder dip** | Price drop at or shortly after release as hype-buyers sell their pulls |
| **Fire sale** | Mass selling by people who opened boxes and want to recoup immediately |
| **Powercreep thesis** | In a non-rotating format, a new set for a top-tier IP strictly improves the existing deck, sustaining or increasing demand for the IP's cards across all prints |
| **Missing piece thesis** | A mid-tier deck with high conversion efficiency but low field share may be one key card away from full viability; that card could arrive in a future release, driving retroactive demand for existing singles |
| **Competitive tier** | Classification of an IP's tournament standing: `high`, `mid-high`, `mid`, `low`, `none` — derived from weissteatime field % and top-cut data across BCS/BSF/Worlds |
| **Field %** | Percentage of tournament players who registered a given set as their primary deck |
| **Conversion rate** | First-place finishes ÷ total entries for that set — high conversion at low field % signals an efficient/underplayed archetype |
| **BCS** | Bushiroad Championship Series — the main EN regional circuit |
| **BSF** | Bushiroad Spring Fest — EN store-level circuit feeding into BCS |
