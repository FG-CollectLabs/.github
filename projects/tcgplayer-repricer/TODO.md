# TCGPlayer Repricer — TODO

## V1 — Pure Frontend Repricer

### Setup
- [ ] Create repo `fg-tcgplayer-repricer` under FG-CollectLabs
- [ ] Scaffold Vite + React + TypeScript + Tailwind
- [ ] Add Papa Parse for CSV parsing
- [ ] GitHub Pages deploy workflow

### Core UI
- [ ] Drag-and-drop CSV upload zone
- [ ] CSV preview table (current prices, columns: name, set, condition, rarity, qty, current price, new price, delta)
- [ ] Rule builder panel:
  - [ ] Reference price selector (TCG Low / TCG Market / TCG Direct Low / TCG Low With Shipping)
  - [ ] Adjustment type: fixed $ or percentage %
  - [ ] Adjustment value (positive = above reference, negative = below)
  - [ ] Floor price toggle + input
  - [ ] Ceiling price toggle + input (optional)
- [ ] Live preview: recalculate new prices as rules change
- [ ] "Download CSV" button — outputs same format as TCGPlayer import expects

### Logic
- [ ] Parse all columns from TCGPlayer Pricing Custom Export format
- [ ] Apply repricing rule to each row
- [ ] Clamp to floor / ceiling
- [ ] Handle edge cases: $0 reference prices, missing columns, non-numeric values
- [ ] Preserve all columns not being modified (pass-through)

### Polish
- [ ] Show summary stats: # cards repriced, avg delta, total estimated value before/after
- [ ] Highlight rows where price changed significantly (>20%)
- [ ] Warn on rows where floor would be violated by reference price

---

## V2 — Analytics Backend

### Backend Setup
- [ ] Scaffold Go backend in `fg-tcgplayer-repricer/backend/`
- [ ] Add gin router + CORS middleware
- [ ] Dockerfile + Cloud Run deploy workflow

### SKU → Product ID Resolution
- [ ] Implement SKU lookup via TCGPlayer public API
- [ ] Cache SKU → product ID mapping in PG or local file
- [ ] Fallback: search by product name + set name

### Sell-Through Scraping
- [ ] Fetch TCGPlayer product page for a given product ID
- [ ] Extract 30-day sold data from page (graph JSON or page data)
- [ ] Calculate avg_daily_sold
- [ ] Fetch current active listings (price + quantity sorted)
- [ ] Cache results (TTL: 6h) to avoid hammering TCGPlayer

### Days-to-Sell Pricing Logic
- [ ] Implement queue-walk algorithm (see ARCHITECTURE.md)
- [ ] Expose `POST /api/reprice` endpoint
- [ ] Expose `GET /api/analytics/{skuId}` endpoint

### Frontend V2 Integration
- [ ] "Days to Sell" input in rule builder (premium rule)
- [ ] API key input (for paywall gating)
- [ ] Async enrichment: upload CSV → fetch analytics per SKU → show results
- [ ] Progress indicator for analytics fetches (can be slow for large CSVs)

### Auth / Paywall
- [ ] Simple API key validation in backend
- [ ] Stripe webhook to issue API keys on subscription
- [ ] Frontend: prompt for API key, persist in localStorage

---

## Research / Spikes

- [ ] Confirm TCGPlayer public API endpoint for SKU → product ID lookup
- [ ] Verify what data is available on TCGPlayer product pages (30d sell-through format)
- [ ] Check if TCGPlayer has a seller API for automated price writes (OAuth flow)
- [ ] Evaluate: is Playwright needed for scraping or does a simple HTTP GET suffice?
