# Agent Checkpoint — 2026-05-19
## EV Calculator — Shipping/Net Pricing Strategy → Implementation

---

## What was done this session

### 1. Verified prior bug fixes are live

All three fixes from the previous session (`2026-05-19-ev-calculator-bug-fixes.md`) are deployed:

- ✅ market-tracker-backend SQL fix (`82cdb4a`) — CI green, batch endpoint returning priced data
- ✅ ev-calculator FallbackPricer fix (`7fee3f3`) — CI green, primary failures now fall back
- ✅ commander-display.js TDZ crash fix (`20f5caf`) — Pages deploy succeeded, full deck data renders

Smoke-tested `https://ev-api.futuregadgetlabs.com/v1/ev/displays/blc-commander-display` — returns full per-card priced line items with sellthrough recs.

### 2. Pricing strategy locked in (planning only — no code changes)

See [`projects/ev-calculator/shipping-net-strategy.md`](../projects/ev-calculator/shipping-net-strategy.md) for full doc.

**Shipping cost defaults agreed:**
- PWE shipment: **$0.93** (materials $0.15 + USPS Forever stamp $0.78)
- Tracked shipment (bubble + USPS Ground Advantage): **$3.75**
- Buyer-paid shipping charge for sub-$5 sales: **$1.50** (gives $0.57 margin for labor)

**Three pricing regimes** (the core algorithm change):

| Card price | Mode | TCG net per copy |
|---|---|---|
| < $5 | Buyer pays $1.50 shipping | `market × (1 − fees) + ($1.50 − $0.93)` |
| $5 – $20 | Free ship via PWE | `market × (1 − fees) − $0.93` |
| ≥ $20 | Free ship via tracked bubble | `market × (1 − fees) − $3.75` |

Thresholds: $5 = TCGPlayer free-shipping badge cutoff; $20 = match eBay bubble threshold (Phil's choice — tracking not technically mandated at $20 but consistent + safer).

### 3. Decisions made

| # | Decision | Choice |
|---|---|---|
| D-001 | Net field shape in API response | **Structured breakdown** — new `tcgplayer_net` object replaces flat `tcgplayer_net_cents` int |
| D-002 | Sub-$5 buyer-paid shipping fee | $1.50 |
| D-003 | Tracked threshold | $20 (matches eBay) |
| D-004 | Manapool shipping treatment | Keep current (Manapool bundles fulfillment, no cost to us) |
| D-005 | eBay shipping treatment | Keep current (already deducts ESE/bubble in `fees.go:79`) |

### 4. Repo state

| Repo | Branch | Last commit | Notes |
|---|---|---|---|
| `FG-CollectLabs/.github` | `main` | `3da8ce8` Projects: add hocg-ev-calculator and tcgplayer-repricer planning docs | Pushed to origin |
| `FG-CollectLabs/ev-calculator` | `main` | `20f5caf` commander-display: fix TDZ crash | Last session's fix; unchanged this session |
| `FG-CollectLabs/market-tracker-backend` | `master` | `82cdb4a` prices: fix stray t-char SQL bug | Last session's fix; uncommitted graded-tracker WIP still in working tree |

**Nothing pushed to ev-calculator or market-tracker-backend this session.** All work was docs in the `.github` repo.

---

## What's next — pick up here

### Implementation plan (in priority order)

#### Step 1 — `internal/fees/shipping.go` (new file)
Create `ShippingProfile` struct + `DefaultTCGPlayerShipping` instance with the locked defaults. Shape proposed in [`shipping-net-strategy.md`](../projects/ev-calculator/shipping-net-strategy.md#proposed-go-shape):

```go
type ShippingProfile struct {
    Name              string
    PWECostCents      int32  // 93
    TrackedCostCents  int32  // 375
    BuyerPaidCents    int32  // 150
    TrackedThreshold  int32  // 2000
    FreeShipThreshold int32  // 500
}
```

Add a method `NetCents(grossCents int32, feeProfile Profile) (regime string, listPrice, fees, shipCost, buyerPaid, net int32)`.

#### Step 2 — `internal/ev/report.go` — replace flat field with structured

Current ([`report.go:82-83`](../../ev-calculator/internal/ev/report.go#L82)):
```go
TCGPlayerNetCents *int32 `json:"tcgplayer_net_cents,omitempty"`
```

Replace with:
```go
type TCGPlayerNetBreakdown struct {
    Regime             string `json:"regime"`           // "buyer_paid"|"free_ship_pwe"|"free_ship_tracked"
    ListPriceCents     int32  `json:"list_price_cents"`
    FeesCents          int32  `json:"fees_cents"`
    ShipCostCents      int32  `json:"ship_cost_cents"`
    BuyerShipPaidCents int32  `json:"buyer_ship_paid_cents"`
    NetPerCopyCents    int32  `json:"net_per_copy_cents"`
}

TCGPlayerNet *TCGPlayerNetBreakdown `json:"tcgplayer_net,omitempty"`
```

Update the calculation at [`report.go:429`](../../ev-calculator/internal/ev/report.go#L429) — currently:
```go
tcgNet := singlesProf.NetCents(grossPerCopy)
li.TCGPlayerNetCents = &tcgNet
```

Replace with regime-aware call into `ShippingProfile.NetCents(...)`.

Also update `NetPerCopyCents` at [`report.go:444`](../../ev-calculator/internal/ev/report.go#L444) to pull from the new breakdown's `NetPerCopyCents` so the totals in `IncludedNetCents` stay correct.

#### Step 3 — Frontend updates

The frontend reads `tcgplayer_net_cents` in:
- `ev-calculator/frontend/static/js/commander-display.js`
- `ev-calculator/frontend/static/js/commander.js` (probably — need to grep)

Change those reads to use `tcgplayer_net.net_per_copy_cents`. Optionally surface the regime badge (PWE / tracked / buyer-paid) in the singles table.

#### Step 4 — Test locally before pushing

```powershell
cd c:\Users\nguye\VSCode\FG-CollectLabs\ev-calculator
go test ./internal/...
go run ./cmd/api  # then curl /v1/ev/displays/blc-commander-display
```

Spot-check three cards: one under $5, one in $5-$20 band, one ≥$20. Confirm the regime matches and the net math is correct.

#### Step 5 — Push + verify

- `git push origin main` on ev-calculator → CI builds API image + Pages redeploys
- Verify at `https://ev-api.futuregadgetlabs.com/v1/ev/displays/blc-commander-display`
- Verify at `https://ev-calculator.futuregadgetlabs.com/commander/display/?key=blc-commander-display`

### Open questions for next session

1. **Sealed deck net** — should sealed decks also apply tracked shipping (bubble mailer cost $3.75)? They're always over $20. Currently `SealedNetCents` only deducts fees. Probably yes — same logic applies.
2. **Manapool net** — should the 8% fee deduction account for any Manapool-side shipping/labor? Phil said Manapool bundles fulfillment; need to confirm whether their 8% truly nets clean or if there's labor cost still on our side.
3. **Repricer endpoint** — `POST /v1/reprice` design is sketched in [`shipping-net-strategy.md`](../projects/ev-calculator/shipping-net-strategy.md#repricer-integration-future) but not implemented. Likely a v0.3.0 feature, separate from this shipping-net work.

---

## Reference paths

| Path | What |
|---|---|
| `ev-calculator/internal/fees/fees.go` | Existing fee profiles + eBay shipping |
| `ev-calculator/internal/ev/report.go` | Report builder — where net is computed per line item |
| `ev-calculator/internal/pricing/pricing.go` | `PriceRow` shape (all the depth/velocity fields we'll need for repricer) |
| `ev-calculator/internal/listings/tcgplayer.go` | Live FetchDepth — gives per-listing `price + shippingPrice` |
| `.github/projects/ev-calculator/shipping-net-strategy.md` | **Full strategy doc — single source of truth** |
| `.github/projects/ev-calculator/roadmap.md` | EV calc roadmap; add a new task ID for "three-regime shipping net" |

### Suggested new roadmap task
`EV-030 Three-regime shipping net calculation` — slot under v0.2.0 (depends on EV-011 market-tracker depth fields already done).
