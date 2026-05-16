# AnonTCG Deal Analyzer — Architecture

> **Status:** V1 implemented
> **Codename:** `anontcg-deal-analyzer`
> **Goal:** Show the best deals in AnonTCG's monthly subscriber program.
> Subscribers get $1,000 off any purchase. The tool compares the effective
> subscriber price against (a) TCGPlayer sealed market price and (b) the
> combined market value of everything inside the box.

---

## North-star questions the tool answers

1. **Is this cheaper than TCGPlayer?** Given $1k off, what % discount am I getting vs. buying the same product on TCGPlayer (including their 6% tax + $15 shipping)?
2. **Is the box good value to break?** What's the market value of all packs, promos, and accessories inside vs. the subscriber price?
3. **Which product is the best overall deal right now?** Rank all active listings by best discount metric.

---

## Two analysis modes

| Mode | Formula | When useful |
|------|---------|-------------|
| **Sealed discount** | `(TCGPlayer case all-in − subscriber price) / TCGPlayer case all-in` | When you'd buy sealed and hold or resell the product |
| **Contents EV discount** | `(pack EV + promos + figures − subscriber price) / contents value` | When you're opening boxes and want to know if the pulls justify the price |

Best discount = `max(sealed_discount, contents_discount)` — whichever metric favors you more.

---

## Repos

| Repo | Role | Status |
|------|------|--------|
| `FG-CollectLabs/anontcg-deal-analyzer` | Full project: catalog, MCP servers, agent, Hugo dashboard | Active |

Single-repo for V1.

---

## System diagram

```
┌───────────────────────────────────────────────────────────────────┐
│  YAML Product Catalog (data/products/*.yaml)                       │
│  45 hardcoded products with:                                       │
│    • AnonTCG listed price, active flag, unit count                 │
│    • Per-unit pack contents (set, count, ev_cents=0 initially)    │
│    • Promo cards, figure values                                    │
└──────────────────────┬────────────────────────────────────────────┘
                       │
         ┌─────────────┴─────────────┐
         │                           │
         ▼                           ▼
┌─────────────────┐        ┌──────────────────────┐
│ MCP: anontcg    │        │ MCP: tcgplayer        │
│                 │        │                       │
│ • list_products │        │ • get_sealed_price    │
│   (Shopify API) │        │   (Playwright scrape) │
│ • get_contents  │        │ • get_pack_ev         │
│   (reads YAML)  │        │   (top card heuristic)│
│ • calculate_deal│        │                       │
└────────┬────────┘        └──────────┬────────────┘
         │                            │
         └─────────────┬──────────────┘
                       │
         ┌─────────────┴─────────────────┐
         │                               │
         ▼                               ▼
┌─────────────────────────┐    ┌──────────────────────────────────┐
│ Claude Agent (per-product│    │ Batch Scripts                     │
│ deep analysis)           │    │                                   │
│                          │    │ scripts/refresh_tcgplayer_prices  │
│ agents/deal_analysis/    │    │   → blog/static/tcgplayer-prices  │
│   run.py                 │    │      .json                        │
│ Usage:                   │    │                                   │
│   python -m agents.      │    │ scripts/generate_dashboard        │
│   deal_analysis.run <key>│    │   → blog/static/deals.json        │
└──────────────────────────┘    └───────────────┬──────────────────┘
                                                │
                                                ▼
                                 ┌──────────────────────────────┐
                                 │ Hugo Dashboard                │
                                 │ blog/layouts/index.html       │
                                 │                               │
                                 │ Sortable table by:            │
                                 │  • Best discount (default)   │
                                 │  • Sealed vs TCGPlayer        │
                                 │  • Contents EV discount       │
                                 │  • Subscriber price           │
                                 │                               │
                                 │ Filter by: game, in-stock    │
                                 │                               │
                                 │ hugo serve -s blog            │
                                 └──────────────────────────────┘
```

---

## Data sources

| Source | Access | Notes |
|--------|--------|-------|
| AnonTCG products | `https://www.anontcg.com/collections/monthly-sub-program-special-pokemon/products.json` | Shopify JSON, no auth, live prices |
| AnonTCG subscriber discount | Hardcoded: $1,000 off any item | Confirmed flat $1k coupon |
| TCGPlayer sealed prices | Playwright headless scrape | Unit (one box/ETB) price, not case |
| Pack EV | TCGPlayer top card price heuristic (get_pack_ev MCP) | Rough estimate; refine with real pull rates |
| Box contents | Hardcoded in `data/products/*.yaml` | Manually researched per product |

---

## Product catalog

45 products across 5 games as of 2026-05-12:

| Game | Count | Notes |
|------|-------|-------|
| Pokémon | 40 | Mix of SV, SWSH, XY era sealed products |
| Weiss Schwarz | 2 | EN booster box case + inner case |
| Yu-Gi-Oh! | 1 | LOB 25th Anniversary |
| Lorcana | 1 | S11 Winterspell booster box case |
| One Piece | 1 | Two Legends (OP-08) booster box case |

42 active (in stock), 3 sold out as of 2026-05-12. Prices change; run `generate_dashboard.py` to refresh.

---

## Pricing math

```
subscriber_price   = anontcg_listed_price − $1,000
sub_per_unit       = subscriber_price / units

tcg_per_unit_all_in = tcg_unit_price × 1.06 + $15   (6% tax + shipping estimate)
tcg_case_all_in     = tcg_per_unit_all_in × units

sealed_discount %  = (tcg_case_all_in − subscriber_price) / tcg_case_all_in × 100

per_unit_ev        = Σ(pack_count × pack_ev_cents) + promo_values + figure_value
case_contents_ev   = per_unit_ev × units

contents_discount % = (case_contents_ev − subscriber_price) / case_contents_ev × 100

best_discount      = max(sealed_discount, contents_discount)
```

Verdict thresholds:
- `STRONG_BUY`: best_discount ≥ 20%
- `BUY`: best_discount ≥ 10%
- `NEUTRAL`: best_discount ≥ 0%
- `PASS`: best_discount < 0%
- `UNKNOWN`: no price data

---

## Key architectural decisions

1. **YAML catalog instead of database** — 45 products fits in flat files; simpler to edit and version. (V1)
2. **Two separate scripts** for TCGPlayer prices vs dashboard generation — price refresh is slow (Playwright); decoupling means you can regenerate the dashboard with cached prices anytime.
3. **Hugo static dashboard** — no backend needed for the UI; `deals.json` is served as a static asset.
4. **Claude agent for per-product deep dives** — the batch scripts give the overview; the agent goes deep on one product using all MCP tools.
5. **Flat $1,000 discount** — confirmed as the subscriber coupon model; no tiers or percentages.
6. **TCGPlayer tax + shipping estimate** — 6% tax + $15 flat shipping is conservative; real cost may vary by state/order size.
7. **Pack EV = 0 by default** — contents discount only shows when EV is explicitly entered or scraped; avoids false "great deal" signals on unknown products.
