# TCGPlayer Repricer — Architecture

## Problem

TCGPlayer's native repricing tools are primitive: match lowest, match market, or manual adjustments. They give no insight into sell velocity. A seller trying to liquidate efficiently has no way to answer "if I price at $X, how many days until I'm the lowest and this card sells?"

## Solution

A standalone repricing tool that:
1. Accepts a TCGPlayer Pricing Custom Export CSV via drag-and-drop
2. Applies configurable repricing rules (floor, reference price ± offset)
3. Outputs a modified CSV ready to re-upload to TCGPlayer
4. (Premium) Uses sell-through analytics to target a specific "days to sell" per card

---

## Repos

| Repo | Purpose |
|------|---------|
| `fg-tcgplayer-repricer` | Vite/TS frontend + Go backend proxy (monorepo or two dirs) |

---

## CSV Format (TCGPlayer Pricing Custom Export)

Key columns:
- `TCGplayer Id` — **SKU ID** (product + condition + printing). This is NOT the product ID in the URL.
- `Product Name`, `Set Name`, `Condition`, `Rarity`
- `TCG Market Price` — market price
- `TCG Low Price` — lowest listing (no shipping)
- `TCG Low Price With Shipping` — lowest listing including shipping
- `TCG Direct Low` — TCGPlayer Direct lowest
- `Total Quantity` — current quantity listed
- `TCG Marketplace Price` — our current listed price (this is what we update)

Output: same CSV with `TCG Marketplace Price` column updated per rules.

### SKU ID vs Product ID

`TCGplayer Id` in the CSV is the SKU ID. Product page URLs use a separate product ID (e.g., `https://www.tcgplayer.com/product/559867`). To map SKU → product ID, use:
```
GET https://api.tcgplayer.com/catalog/skus/{skuId}
```
Or the public product search endpoint. Alternatively, store a local SKU → product ID cache populated on first use.

---

## V1 — Pure Frontend (No Backend)

All repricing is deterministic from the CSV data. No scraping needed.

**Stack:** Vite + React + TypeScript + Tailwind + Papa Parse (CSV)

**Features:**
- Drag-and-drop CSV upload
- Rule builder UI:
  - **Reference price:** TCG Low | TCG Market | TCG Direct Low | TCG Low With Shipping
  - **Adjustment:** fixed offset (±$) or percentage offset (±%)
  - **Floor price:** never go below $X
  - **Ceiling price:** never go above $X (optional)
  - **Minimum margin:** floor = cost × multiplier (future, requires cost column)
- Per-condition or per-rarity overrides
- Preview table: shows current price → new price with delta
- Download updated CSV

**No backend, no auth, no infra. Single HTML file deploy.**

---

## V2 — Analytics Backend (Premium "Days to Sell" Logic)

**Stack:** Go backend (gin or net/http) + same Vite frontend

### Sell-Through Scraping

TCGPlayer product pages expose a 30-day sold graph. We need to:
1. Map SKU ID → Product ID (via TCGPlayer API or cached lookup)
2. Fetch `https://www.tcgplayer.com/product/{productId}` and extract:
   - 30-day sell-through count from the graph data
   - Average daily sold = 30-day count ÷ 30
3. Current lowest listing price from live listing data

### "Days to Sell" Pricing Logic

Given:
- `target_days`: how many days until the card sells
- `avg_daily_sold`: average copies sold per day across all sellers
- `current_listings`: sorted list of (price, quantity) for all sellers
- `our_quantity`: how many we're listing

Algorithm:
1. Compute total market demand over `target_days` = `avg_daily_sold × target_days`
2. Walk the listings from lowest to highest, accumulating quantity until we exceed total demand
3. The price at which we fall inside that demand window = our target price
4. Clamp to floor

This effectively asks: "if the market sells X copies in the next N days, what price puts us in the queue to sell within N days?"

### Backend Endpoints

```
POST /api/reprice        — accepts CSV rows, returns repriced rows
GET  /api/analytics/{skuId} — returns sell-through data for a SKU
GET  /api/product/{skuId}   — resolves SKU → product ID + metadata
```

### Auth / Paywall

- V2 premium features gated behind a simple API key or Stripe subscription check
- API key stored in localStorage, validated against backend

---

## Data Flow

```
User uploads CSV
    │
    ▼
Parse CSV (Papa Parse)
    │
    ├── V1 rules only ──→ apply floor/reference/offset locally ──→ download CSV
    │
    └── V2 analytics ──→ POST /api/reprice ──→ backend fetches TCGPlayer data
                                              → applies days-to-sell logic
                                              → returns updated prices
                                              → frontend downloads CSV
```

---

## Deployment

| Stage | Frontend | Backend |
|-------|----------|---------|
| V1 | GitHub Pages (static) | none |
| V2 | GitHub Pages or CF Pages | Cloud Run (Go container) |

---

## Out of Scope (V1)

- Bulk price history
- Automated scheduled repricing (requires TCGPlayer API OAuth)
- Direct TCGPlayer API write access (they have a seller API but it's gated)
- Multi-marketplace (eBay, Manapool) — future
