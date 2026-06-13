# Card Inventory V2 — Database Schema

> Database: `card_inventory_v2` on `pg-card-inventory` (Proxmox)
> Migrations: managed by goose in `card-inventory-backend/migrations/`

## Overview

Three item tables (different physical shapes), one set of shared tables for purchase orders, sales, and market price cache. No multi-tenancy — no `org_id`, no RLS.

```
purchase_orders ──< purchase_lines ──> {sealed_items | singles_items | graded_items}
                                              │
                                  market_prices (cache, joined at query time)
                                              │
                                           sales
                                              │
                                    breaks (sealed → singles linkage)
```

---

## purchase_orders

One row per acquisition event (eBay order, Facebook Marketplace deal, local pickup, etc.).

```sql
CREATE TABLE purchase_orders (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    source         TEXT        NOT NULL,           -- 'ebay' | 'facebook' | 'local' | 'tcgplayer' | 'other'
    source_url     TEXT,                           -- listing URL if applicable
    seller         TEXT,
    purchased_at   TIMESTAMPTZ NOT NULL,
    item_total     NUMERIC(10,2) NOT NULL DEFAULT 0,
    shipping_paid  NUMERIC(10,2) NOT NULL DEFAULT 0,
    platform_fees  NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_paid     NUMERIC(10,2) GENERATED ALWAYS AS (item_total + shipping_paid + platform_fees) STORED,
    notes          TEXT,
    status         TEXT        NOT NULL DEFAULT 'received',  -- 'pending' | 'received' | 'cancelled'
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## sealed_items

Sealed booster boxes, collector boosters, bundles, commander decks, etc.

```sql
CREATE TABLE sealed_items (
    id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tcgplayer_product_id  INTEGER,                -- NULL if not in TCGPlayer catalog
    product_name          TEXT        NOT NULL,
    set_code              TEXT,
    game                  TEXT        NOT NULL DEFAULT 'mtg',  -- 'mtg' | 'pokemon' | 'fab' | 'ws' | 'other'
    qty                   INTEGER     NOT NULL DEFAULT 1,
    cost_per_unit         NUMERIC(10,2) NOT NULL,
    po_id                 UUID        REFERENCES purchase_orders(id) ON DELETE SET NULL,
    acquired_at           TIMESTAMPTZ NOT NULL,
    status                TEXT        NOT NULL DEFAULT 'in_stock',
    -- 'in_stock' | 'listed' | 'sold' | 'broken' | 'consigned' | 'returned'
    notes                 TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX sealed_items_status_idx     ON sealed_items(status);
CREATE INDEX sealed_items_po_id_idx      ON sealed_items(po_id);
CREATE INDEX sealed_items_tcg_id_idx     ON sealed_items(tcgplayer_product_id) WHERE tcgplayer_product_id IS NOT NULL;
```

---

## singles_items

Individual raw (non-graded) cards.

```sql
CREATE TABLE singles_items (
    id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tcgplayer_product_id  INTEGER,
    card_name             TEXT        NOT NULL,
    set_code              TEXT,
    set_name              TEXT,
    collector_number      TEXT,
    finish                TEXT        NOT NULL DEFAULT 'normal',
    -- 'normal' | 'foil' | 'etched' | 'borderless' | 'showcase' | 'surge_foil' | 'other'
    condition             TEXT        NOT NULL DEFAULT 'NM',
    -- 'NM' | 'LP' | 'MP' | 'HP' | 'DMG'
    game                  TEXT        NOT NULL DEFAULT 'mtg',
    qty                   INTEGER     NOT NULL DEFAULT 1,
    cost_basis            NUMERIC(10,2) NOT NULL,
    po_id                 UUID        REFERENCES purchase_orders(id) ON DELETE SET NULL,
    break_id              UUID        REFERENCES breaks(id) ON DELETE SET NULL,
    acquired_at           TIMESTAMPTZ NOT NULL,
    status                TEXT        NOT NULL DEFAULT 'in_stock',
    -- 'in_stock' | 'listed' | 'sold' | 'consigned' | 'returned'
    notes                 TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX singles_items_status_idx    ON singles_items(status);
CREATE INDEX singles_items_po_id_idx     ON singles_items(po_id);
CREATE INDEX singles_items_break_id_idx  ON singles_items(break_id) WHERE break_id IS NOT NULL;
CREATE INDEX singles_items_tcg_id_idx    ON singles_items(tcgplayer_product_id) WHERE tcgplayer_product_id IS NOT NULL;
CREATE INDEX singles_items_name_idx      ON singles_items USING gin(to_tsvector('english', card_name));
```

---

## graded_items

PSA/CGC/BGS/SGC-graded cards. Each graded slab is one row (qty always 1).

```sql
CREATE TABLE graded_items (
    id                        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    tcgplayer_product_id      INTEGER,    -- the graded-version product ID (e.g. "Charizard PSA 10")
    raw_tcgplayer_product_id  INTEGER,    -- the raw card's product ID for fallback price reference
    card_name                 TEXT        NOT NULL,
    set_code                  TEXT,
    set_name                  TEXT,
    collector_number          TEXT,
    game                      TEXT        NOT NULL DEFAULT 'mtg',
    grading_co                TEXT        NOT NULL,
    -- 'PSA' | 'CGC' | 'BGS' | 'SGC' | 'ACE' | 'other'
    cert_number               TEXT        UNIQUE,   -- nullable until cert is known
    grade                     NUMERIC(4,1),         -- 10, 9.5, 9, 8.5, ... NULL while submitted
    cost_basis                NUMERIC(10,2) NOT NULL,
    -- includes purchase price of raw card + grading fee + shipping
    po_id                     UUID        REFERENCES purchase_orders(id) ON DELETE SET NULL,
    acquired_at               TIMESTAMPTZ NOT NULL, -- date raw card was acquired (not graded date)
    graded_at                 TIMESTAMPTZ,          -- when grade was received back
    status                    TEXT        NOT NULL DEFAULT 'in_stock',
    -- 'in_stock' | 'submitted' | 'listed' | 'sold' | 'consigned' | 'returned'
    notes                     TEXT,
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX graded_items_status_idx     ON graded_items(status);
CREATE INDEX graded_items_po_id_idx      ON graded_items(po_id);
CREATE INDEX graded_items_cert_idx       ON graded_items(cert_number) WHERE cert_number IS NOT NULL;
CREATE INDEX graded_items_tcg_id_idx     ON graded_items(tcgplayer_product_id) WHERE tcgplayer_product_id IS NOT NULL;
```

---

## breaks

Records the event of cracking a sealed product into singles.

```sql
CREATE TABLE breaks (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    sealed_item_id UUID        NOT NULL REFERENCES sealed_items(id),
    qty_broken     INTEGER     NOT NULL DEFAULT 1,  -- how many boxes cracked in this event
    broken_at      TIMESTAMPTZ NOT NULL,
    notes          TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX breaks_sealed_item_idx ON breaks(sealed_item_id);
```

Singles produced in a break have `break_id` set. Cost basis per single = `(sealed_item.cost_per_unit * qty_broken) / singles_count`, or manually set.

---

## sales

One row per sale transaction. `mode` + `item_id` discriminates which item table to look up.

```sql
CREATE TABLE sales (
    id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    mode            TEXT        NOT NULL,  -- 'sealed' | 'singles' | 'graded'
    item_id         UUID        NOT NULL,  -- FK into sealed_items / singles_items / graded_items
    platform        TEXT        NOT NULL,  -- 'tcgplayer' | 'ebay' | 'manapool' | 'local' | 'other'
    sold_at         TIMESTAMPTZ NOT NULL,
    sale_price      NUMERIC(10,2) NOT NULL,
    platform_fees   NUMERIC(10,2) NOT NULL DEFAULT 0,
    shipping_out    NUMERIC(10,2) NOT NULL DEFAULT 0,
    net_proceeds    NUMERIC(10,2) GENERATED ALWAYS AS (sale_price - platform_fees - shipping_out) STORED,
    buyer           TEXT,
    notes           TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX sales_mode_item_idx ON sales(mode, item_id);
CREATE INDEX sales_sold_at_idx   ON sales(sold_at DESC);
CREATE INDEX sales_platform_idx  ON sales(platform);
```

When a sale is created, the backend sets the item's `status = 'sold'` in the appropriate item table.

---

## market_prices

Cache of TCGPlayer market prices, refreshed from market-tracker-backend.

```sql
CREATE TABLE market_prices (
    tcgplayer_product_id  INTEGER     PRIMARY KEY,
    market_price          NUMERIC(10,2),
    low_price             NUMERIC(10,2),
    mid_price             NUMERIC(10,2),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Stale threshold: 24h. Background goroutine refreshes all product IDs in `in_stock` / `listed` items every 4h.

---

## Computed values (not stored — derived in queries)

| Value | Formula |
|---|---|
| `item.current_value` | `market_prices.market_price` for `in_stock`/`listed` items |
| `item.unrealized_pnl` | `market_price - cost_basis` |
| `sale.realized_pnl` | `net_proceeds - item.cost_basis` |
| `po.effective_cost_per_item` | `total_paid / item_count` (splits PO overhead across items) |
| `break.break_roi` | `Σ(singles sold net_proceeds) / sealed cost_basis - 1` |

---

## Status transitions

```
sealed:  in_stock → listed → sold
                  → broken (qty reaches 0 via break events)
                  → consigned
                  → returned → in_stock

singles: in_stock → listed → sold
                  → consigned
                  → returned → in_stock

graded:  in_stock → submitted → in_stock (grade received)
                  → listed → sold
                  → consigned
                  → returned → in_stock
```
