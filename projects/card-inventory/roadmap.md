# Card Inventory — Release Roadmap

High-level milestones. Granular task tracking lives in [TODO.md](./TODO.md).

---

## v0.1 — Foundation ✅ (2026-05-18)

Core multi-tenant inventory loop is live at `inventory.futuregadgetlabs.com`.

- Firebase Google auth gate
- Multi-tenant org model with auto-provisioning on first sign-in
- Inventory items: condition, grade, location, status, cost basis
- Acquisitions with line items (sealed / singles / break / other)
- Catalog browser in Add Line form: kind → game → set filter pills, EV API market price hint
- Locations: hierarchy (room → box → binder), expand/collapse tree
- Listings: create/track eBay/other channel listings with status lifecycle
- Transactions: eBay order CSV import → transaction + inventory status update
- Goose migrations on API startup (Watchtower-safe deploys)
- Cloudflare tunnel: `inventory.futuregadgetlabs.com` + `inventory-api.futuregadgetlabs.com`

---

## v0.2 — Sell Flow & P&L

Complete the buy → list → sell loop with realized gain tracking.

- **Mark sold UI**: click item → enter sale price → creates transaction + flips status to `sold`
- **Quick list**: from inventory item detail, one-click create listing with prefilled price
- **Realized P&L per item**: sale price − cost basis − fees → net gain/loss displayed on item
- **Transaction detail**: show linked inventory item, listing, acquisition line
- **Listing status sync**: manually mark listing as sold/cancelled/expired

---

## v0.3 — Item Identity & Card Lookup

Link raw `printing_id` fields to human-readable card data.

- **Card identifier integration**: resolve `printing_id` → card name, set, image via card-identifier-backend
- **Market price on item detail**: pull current market price from market-tracker for singles
- **Inventory item search**: full-text search by card name (not just filter by status/location)
- **`catalog_key` on acquisition lines**: store EV catalog key for sealed products; enables XIRR valuation
- **`break_id` on inventory items**: group singles from same physical break for break P&L

---

## v0.4 — Analytics & Portfolio Intelligence

Turn raw data into actionable investment metrics.

- **Analytics tab**: portfolio-level cost basis vs realized + unrealized gains
- **XIRR per acquisition**: time-weighted return on each purchase event
- **Per-platform performance**: eBay vs other channels, fees, net margin
- **Location utilization**: items per box/binder, value density
- **Graded premium tracking**: join with graded-regrade-tracker for PSA/CGC grade uplift P&L

---

## v0.5 — Scale & Ops

Hardening for higher volume and multi-user use.

- **Bulk operations**: multi-select → bulk move location / bulk list / bulk mark sold
- **eBay OAuth listing push**: create listings on eBay directly from inventory (not just import)
- **Pagination everywhere**: currently inventory fetches first 500; proper cursor/page controls
- **Invite flow**: add org members with role-based access (owner / editor / viewer)
- **Audit log**: who changed what and when (append-only event table)
- **Export**: CSV/JSON dump of full inventory + transactions for external analysis
