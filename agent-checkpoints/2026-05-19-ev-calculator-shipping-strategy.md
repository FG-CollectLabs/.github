# Agent Checkpoint — 2026-05-19
## EV Calculator — Shipping/Net Strategy SHIPPED + EV-011 Scope Discovery

---

## What got shipped this session

### 1. Verified prior bug fixes are live

All three fixes from the previous session (`2026-05-19-ev-calculator-bug-fixes.md`) are deployed:

- ✅ market-tracker-backend SQL fix (`82cdb4a`)
- ✅ ev-calculator FallbackPricer fix (`7fee3f3`)
- ✅ commander-display.js TDZ crash fix (`20f5caf`)

### 2. Three-regime TCGPlayer net pricing — DEPLOYED

Commit `3bbb123` on `ev-calculator/main`. Verified live in prod for two of three regimes (no $20+ card exists in any commander case yet, but the code path is identical to the verified PWE branch). The structured `tcgplayer_net` JSON breakdown replaces the flat `tcgplayer_net_cents` int.

| Regime | Sample | Math |
|---|---|---|
| `buyer_paid` (<$5) | Zulaport Cutthroat @ $1.48 | list 148 − fees 20 − ship 93 + buyer-paid 150 = **185¢** |
| `free_ship_pwe` ($5–$20) | Helm of the Host @ $9.59 | list 959 − fees 128 − ship 93 = **738¢** |
| `free_ship_tracked` (≥$20) | (no card hits threshold) | list × (1 − fees) − 375 |

Defaults locked in [`ev-calculator/internal/fees/shipping.go`](../../ev-calculator/internal/fees/shipping.go) (`DefaultTCGPlayerShipping`):
PWE 93¢ · tracked 375¢ · buyer-paid 150¢ · tracked threshold $20 · free-ship threshold $5.

### 3. Sealed-deck $5 small-box shipping — DEPLOYED

Commit `501abe1`. `SealedNetCents` now subtracts $5.00 small-box cost. Verified: BLC sealed deck went from `gross 4889 → expected fee-only net 4211 → actual net 3711` (exactly 500¢ less). Manapool is left at 8% fee-only (per Phil — Manapool has no free-ship economics, no labor cost adjustment needed).

### 4. Repo state

| Repo | Branch | Last commit | Pushed |
|---|---|---|---|
| `FG-CollectLabs/.github` | `main` | `3c05f76` Checkpoint: EV calculator shipping/net strategy handoff (about to be superseded by this checkpoint) | yes |
| `FG-CollectLabs/ev-calculator` | `main` | `501abe1` fees: deduct $5 small-box shipping from sealed-deck net | yes |
| `FG-CollectLabs/market-tracker-backend` | `master` | `82cdb4a` (unchanged this session) | n/a |

market-tracker-backend's graded-tracker WIP is still uncommitted in the working tree — untouched.

---

## EV-011 Scope Discovery (the big finding)

The user asked me to "fix EV-011". The roadmap blurb said:
> Extend market-tracker `PriceRow` to return `listing_count`, `units_sold_week`, `depth_to_plus_{10,25,50}_units` — fix is in `market-tracker-backend/internal/prices/handler.go`

**That description is wrong.** The handler.go code already has these fields in the struct AND the SELECT query. The real EV-011 has three deeper sub-problems:

### EV-011a — depthingest TCGPlayer fetcher gets HTTP 400 on every request

- The last successful `ingest-depth` run was never — every run logs "1557/1557 errors" with `tcgplayer 400: {"title":"Bad Request"}`.
- `listing_depth` table is **empty** (0 rows).
- A prior session already attempted a fix (`75a4e35: drop custom TLS config that Cloudflare now rejects as bot`) — the current deployed image (`philwin/market-tracker-backend:latest` digest from 2026-05-19 16:14 UTC) HAS that fix. It didn't work.
- **Diagnostic:** curl from inside LXC 109 hits `mp-search-api.tcgplayer.com` and returns HTTP 200 with full listing data — exact same headers, exact same payload. So it's NOT the IP, NOT the headers, NOT the payload.
- **Hypothesis:** Cloudflare is fingerprinting the Go HTTP client's TLS handshake (JA3 fingerprint) and rejecting it regardless of `User-Agent`. The "drop custom TLS" fix removed the obviously-wrong pinned ciphers but Go's stdlib TLS still doesn't pass as a browser.
- **Fix path:** swap `net/http` for `github.com/refraction-networking/utls` or `lwthiker/curl-impersonate` to impersonate Chrome's TLS fingerprint. Not a 5-minute change.
- **Curiosity:** ev-calculator's identical fetcher in `internal/listings/tcgplayer.go` is supposedly used for the `LiveDepth` feature. We haven't independently verified whether THAT actually works in prod either — could be silently broken too. Worth confirming.

### EV-011b — semantic mismatch in `depth_to_plus_{10,25,50}_units`

- **Writer side** ([`market-tracker-backend/internal/priceingest/depth.go:124`](../../market-tracker-backend/internal/priceingest/depth.go#L124)): `depthAtUnits(latest.tiers, 10)` returns the PRICE (cents) of the tier where cumulative quantity reaches 10. Field is internally named `DepthToPlus10Cents` (price).
- **Reader side** ([`ev-calculator/internal/sellthrough/sellthrough.go:99`](../../ev-calculator/internal/sellthrough/sellthrough.go#L99)): treats `depth_to_plus_10_units` as a **count of units** within +10% of market price, divides by velocity to estimate weeks-to-sell.
- These are different fields with the same name. Even if the data pipeline succeeds, the sellthrough recommendation will produce garbage numbers.
- **Fix:** rewrite the market-tracker writer to compute count-within-+X%-of-market (which requires the market price — should move into `EnrichWithMarketPrice`). Smaller, mechanical code change.

### EV-011c — velocity requires ≥2 snapshots over time

- `ComputeDepthMetrics` derives `units_sold_week` and `add_back_units_week` by diffing consecutive `listing_depth` snapshots ([`depth.go:128-149`](../../market-tracker-backend/internal/priceingest/depth.go#L128)).
- The cron runs `ingest-depth` once per week (Sun 00:00 UTC). One snapshot per week → zero velocity ever.
- **Fix:** add a second cron firing midweek (Sun + Wed), or change `ComputeDepthMetrics` to fall back to a single-snapshot heuristic when only one row exists.

---

## TODOs (parked, in priority order)

1. **EV-011a** (highest blocker) — Solve Cloudflare TLS-fingerprint block on depthingest. Without it, the whole sellthrough chain stays starved.
2. **EV-011b** — Align `depth_to_plus_{10,25,50}_units` semantics between writer and reader.
3. **EV-011c** — Decide on multi-snapshot cadence (twice-weekly cron or single-snapshot fallback).
4. **Verify ev-calculator's `LiveDepth` works in prod** — if it does, the difference between it and the failed depthingest fetcher will reveal the TLS fix.
5. Sealed-deck shipping is shipped, but verify SealedDecks scenario delta math still makes sense after the −$5 hit. (Briefly: SealedDecksNetCents went down by $5 × deck_count × copies per case.)
6. Repricer endpoint (`POST /v1/reprice`) — sketched in [`projects/ev-calculator/shipping-net-strategy.md`](../projects/ev-calculator/shipping-net-strategy.md#repricer-integration-future). Blocked on EV-011 (needs velocity + refill).

---

## Reference paths

| Path | What |
|---|---|
| `.github/projects/ev-calculator/roadmap.md` | Roadmap — EV-011 now has detailed sub-tasks a/b/c |
| `.github/projects/ev-calculator/shipping-net-strategy.md` | Shipping strategy decisions (Phase 1, shipped) |
| `ev-calculator/internal/fees/shipping.go` | `ShippingProfile` + `Apply()` |
| `ev-calculator/internal/ev/report.go` | Report builder w/ regime-aware net + $5 sealed-deck deduction |
| `ev-calculator/internal/sellthrough/sellthrough.go` | Reader side of EV-011b semantic bug |
| `ev-calculator/internal/listings/tcgplayer.go` | LiveDepth fetcher (need to verify it actually works) |
| `market-tracker-backend/internal/depthingest/tcgplayer.go` | Failing depth ingest (EV-011a) |
| `market-tracker-backend/internal/priceingest/depth.go` | Writer side of EV-011b semantic bug |

---

## What to do next

When the next session starts: pick from the parked TODOs above. The biggest-leverage next move is **EV-011a** because everything downstream depends on it. If you don't want to wade into utls/curl-impersonate territory yet, **EV-011b** is a clean isolated code fix that pays off the moment EV-011a lands.

Either way, today's deploy of regime-aware shipping/net is **the user-visible value already shipped** — that part of the work is done.
