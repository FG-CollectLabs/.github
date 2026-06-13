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

## v0.3.5 — Agent Ingestion

Eliminate manual line-item entry on both sides of the ledger. Detailed plan in [agent-ingestion/ARCHITECTURE.md](./agent-ingestion/ARCHITECTURE.md); tasks in [agent-ingestion/TODO.md](./agent-ingestion/TODO.md).

- **`card-inventory-mcp`**: new TS repo exposing inventory/catalog/market/acquisitions/transactions as MCP tools over stdio
- **Receipt drop → purchase order**: drag a receipt PDF/image into Acquisitions; backend-hosted Sonnet 4.6 agent extracts line items, resolves printings/products, snapshots TCGPlayer market price at receipt date, drafts an acquisition for user review
- **Invoice drop → mark sold**: drag a sales invoice; agent extracts lines, searches inventory for active candidates with bin paths, user picks which physical copy fulfilled each line, transactions auto-created
- **Agent runner in backend**: `ANTHROPIC_API_KEY` env var, prompt caching on system prompt + tool schemas, per-run token cap and per-org daily $ cap
- **Draft tables** (`acquisition_drafts`, `sale_drafts`, `agent_runs`): all writes are user-gated; agent never auto-commits

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

---

## v0.6 — Sealed Module

Surface sealed product as a first-class inventory mode alongside singles. The data model already supports this (`products`, `product_contents`, `sealed_break` transformation, `sealed_appreciation` venture kind) — this milestone is purely frontend UX + sealed-specific workflows.

- **Sealed nav section**: top-level "Sealed" view alongside "Singles"; shared auth/tenant context, same backend
- **Bulk intake**: add a case or a box run in one form — select product SKU, quantity, purchase price, acquisition date; backend creates one `acquisition` + N `inventory_items` (each referencing `product_id`) in a single transaction
- **Sealed holdings dashboard**: per-SKU table showing quantity held, total cost basis, current EV (from `v_product_ev`), EV vs cost delta, and appreciation since acquisition date
- **Break scheduling**: allocate specific boxes to an upcoming break — sets `status = allocated` and creates a `break_id`; Box Break App reads this `break_id` to link cracked singles back to the source box
- **Sell-sealed flow**: mark one or more sealed boxes as sold without breaking — enters sale price, creates `transaction` row, flips item `status = sold`; P&L computed as sale price − cost basis
- **Sealed P&L tab in Analytics**: extends v0.4 analytics with sealed-specific metrics — EV appreciation over hold period, realized gain on sold-sealed, break ROI (box cost vs singles realized), per-SKU performance ranking
