# EV Calculator — Shipping & Net Pricing Strategy

> **Status:** Decisions captured 2026-05-19. Implementation pending — see roadmap EV-0XX (to be added).

---

## Problem

Current `tcgplayer_net_cents` calculation in [`internal/ev/report.go:429`](../../../ev-calculator/internal/ev/report.go#L429)
applies fees only — no shipping is deducted. This implicitly assumes the buyer
is paying separate shipping. That's a valid model for sub-$5 cards, but for
$5+ cards (where TCGPlayer "free shipping" is the competitive norm) we end up
overpriced relative to sellers who bake shipping into the listing.

Manapool and eBay each have their own shipping economics. We need three
different shipping treatments.

---

## Locked-in defaults

### PWE (cards under $20)

| Item | Unit cost @ bulk |
|---|---|
| #10 peel-and-seal windowed envelope | $0.06 |
| Penny sleeve | $0.01 |
| Card saver (semi-rigid) | $0.07 |
| Invoice sheet (1/4 page printer paper) | $0.005 |
| **Materials subtotal** | **~$0.15** |
| USPS Forever stamp | $0.78 |
| **Total per PWE shipment** | **~$0.93** |

### Tracked (cards $20+)

| Item | Unit cost |
|---|---|
| Bubble mailer (#000, 4x8) | $0.08 |
| Card saver + penny sleeve | $0.08 |
| Thermal label | $0.02 |
| Invoice | $0.005 |
| USPS Ground Advantage 2oz tracked | ~$3.55 |
| **Total per tracked shipment** | **~$3.75** |

### Buyer-paid shipping fee (sub-$5 cards)

- Charge buyer: **$1.50**
- Real cost: $0.93
- Net to us: **$0.57** to cover packing time/effort

---

## Three pricing regimes

| Card price | Shipping mode | List price | TCG net per copy |
|---|---|---|---|
| **< $5** | Buyer pays $1.50 shipping | market | `market × (1 - fees) + ($1.50 - $0.93)` |
| **$5 – $20** | Free ship (PWE baked in) | market | `market × (1 - fees) - $0.93` |
| **≥ $20** | Free ship (bubble + tracking baked in) | market | `market × (1 - fees) - $3.75` |

TCGPlayer "free shipping" badge requires $5+ orders. Tracking is not
mandated at $20, but matches the eBay bubble threshold and protects against
loss for cards that hurt to lose.

---

## Proposed Go shape

```go
// internal/fees/shipping.go (new file)
package fees

type ShippingProfile struct {
    Name              string
    PWECostCents      int32  // 93  — materials + 1oz stamp
    TrackedCostCents  int32  // 375 — bubble + tracked label
    BuyerPaidCents    int32  // 150 — what we charge buyer for sub-$5 sales
    TrackedThreshold  int32  // 2000 — card price at which we use tracked shipping
    FreeShipThreshold int32  // 500  — card price at which we bake shipping in
}

var DefaultTCGPlayerShipping = ShippingProfile{
    Name:              "tcgplayer-default",
    PWECostCents:      93,
    TrackedCostCents:  375,
    BuyerPaidCents:    150,
    TrackedThreshold:  2000,
    FreeShipThreshold: 500,
}
```

Manapool: bundles fulfillment — no shipping cost to us. Keep current model.
eBay: already deducts shipping per `EbayShippingCents` in
[`internal/fees/fees.go:79`](../../../ev-calculator/internal/fees/fees.go#L79).

---

## LineItem shape change

Replace the single `tcgplayer_net_cents` field with a regime-aware breakdown
so the frontend can show how the net was derived:

```jsonc
{
  "tcgplayer_net": {
    "regime": "free_ship_pwe",          // "buyer_paid" | "free_ship_pwe" | "free_ship_tracked"
    "list_price_cents": 800,
    "fees_cents": 106,
    "ship_cost_cents": 93,              // 0 for buyer-paid regime
    "buyer_ship_paid_cents": 0,         // 150 for buyer-paid regime
    "net_per_copy_cents": 601
  }
}
```

---

## Repricer integration (future)

Two complementary data sources:

| Source | Strength | Use for |
|---|---|---|
| market-tracker `/v1/prices/batch` (cached weekly) | velocity, refill rate, historical trend | "how fast does this card move" |
| Live `FetchDepth` ([listings/tcgplayer.go](../../../ev-calculator/internal/listings/tcgplayer.go)) | current competitors' total prices | "what price right now to be Nth-cheapest" |

Repricer algorithm sketch:
1. Pull `units_sold_week` + `add_back_units_week` from market-tracker → compute `target_depth = velocity × (target_days / 7)`
2. Call live FetchDepth → sort listings by `price + shippingPrice` (the buyer's total cost)
3. Find Nth listing where N = target_depth
4. Reverse-derive our list price from that buyer-total minus our shipping (PWE/tracked depending on regime)
5. Floor at `lowest_legit_cents` × 0.95 to avoid scammer-listing-driven races

**Gap:** market-tracker's `depth_to_plus_X` fields are computed on price-alone,
not price + shipping. For sub-$5 cards this is misleading. Either backfill
market-tracker (proper fix) or rely on live FetchDepth at pricing time
(simpler, what we're going with for the repricer).
