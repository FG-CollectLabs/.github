# Agent Ingestion — Architecture

> **Status:** Draft v0.1 — pre-implementation
> **Slot:** card-inventory v0.3.5 (between sell-flow v0.2 and analytics v0.4)
> **Goal:** Drop a receipt → auto-create a purchase order with TCGPlayer market snapshot. Drop an invoice → auto-locate items in bins and mark them sold. No manual line-item entry.

## North-star UX

- **Receipt:** drag a PDF/image into the Acquisitions page. Within ~30s, an editable acquisition draft appears with line items, costs, and market-at-acquisition prices already filled in. User reviews → confirms → committed.
- **Invoice:** drag a sales invoice into the Sales page. Agent matches each line to inventory candidates (with bin path: "Office → Box 3 → Binder A → Slot 12"). User confirms which physical copy fulfilled each line → committed as `transactions`, items flip to `sold`.

The user never types card names or prices. They only review and disambiguate.

## Components

```
┌─────────────────────────────┐
│ card-inventory-frontend     │
│   - Drop zone (receipts)    │
│   - Drop zone (invoices)    │
│   - Draft review UI         │
└──────────────┬──────────────┘
               │ multipart upload
               ▼
┌─────────────────────────────┐         ┌──────────────────────────┐
│ card-inventory-backend      │ stdio   │ card-inventory-mcp (TS)  │
│   - /ingest/receipt         │────────▶│   (local subprocess)     │
│   - /ingest/invoice         │         │   MCP tools over stdio   │
│   - acquisition_drafts      │         │   - inventory.*          │
│   - sale_drafts             │         │   - acquisitions.*       │
│   - agent runner            │         │   - listings.*           │
│     (Anthropic SDK Go,      │         │   - transactions.*       │
│      Sonnet 4.6 multimodal) │         │   - catalog.*            │
└──────┬──────────────────────┘         │   - market.price_snapshot│
       │ GCS write                       └────────────┬─────────────┘
       ▼                                              │ HTTP (localhost)
┌─────────────────┐                                   ▼
│ GCS             │                       ┌──────────────────────────┐
│  receipts/      │                       │ card-inventory-backend   │
│  invoices/      │                       │ (same process, REST API) │
└─────────────────┘                       └──────────────────────────┘
```

The MCP server is a thin wrapper over the existing backend REST API. The agent runner lives inside the backend and talks to MCP over stdio. Both speak to the same backend HTTP API — MCP isn't a second source of truth, it's an LLM-shaped façade.

## Repos

| Repo | Status | Role |
|------|--------|------|
| `card-inventory-mcp` | NEW (TS) | MCP server exposing inventory ops as tools. Stdio + optional HTTP. |
| `card-inventory-backend` | EXISTING | New routes: `/ingest/receipt`, `/ingest/invoice`. New tables: `acquisition_drafts`, `sale_drafts`. Hosts agent runner. |
| `card-inventory-frontend` | EXISTING | New drop zones + draft review screens. |

### Why TS for MCP

`@modelcontextprotocol/sdk` is the mature reference implementation. Tool schemas are zod-validated, transport is one line of code. Go MCP SDKs are still catching up. The MCP server is small (~500 LOC) and stateless — language choice has no downstream cost.

### Why backend-hosted agent

- API key (`ANTHROPIC_API_KEY`) stays in backend env, never reaches the browser.
- MCP server can stay on localhost / stdio — no public auth surface to design.
- Receipt/invoice files already land in backend GCS; agent runs near its data.
- Centralized spend metering and rate-limiting if/when this opens to other users.
- Browser-hosted only makes sense paired with BYO keys (rejected for now).

## Data model additions

In `card-inventory-backend`:

```sql
-- migrations/NNN_agent_ingestion.sql

CREATE TABLE acquisition_drafts (
  id              UUID PRIMARY KEY,
  org_id          UUID NOT NULL REFERENCES orgs(id),
  source_kind     TEXT NOT NULL,                -- 'receipt'
  source_gcs_uri  TEXT NOT NULL,
  status          TEXT NOT NULL,                -- parsing | ready | committed | failed | discarded
  draft_payload   JSONB,                        -- agent's proposed acquisitions.create payload
  agent_notes     TEXT,                         -- free-form agent reasoning surfaced to user
  agent_usage     JSONB,                        -- input/output tokens, cost
  committed_acquisition_id UUID REFERENCES acquisitions(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE sale_drafts (
  id              UUID PRIMARY KEY,
  org_id          UUID NOT NULL REFERENCES orgs(id),
  source_gcs_uri  TEXT NOT NULL,
  status          TEXT NOT NULL,                -- parsing | needs_picks | committed | failed | discarded
  invoice_meta    JSONB,                        -- buyer, channel, occurred_at, totals
  line_drafts     JSONB,                        -- [{printing_id, condition, qty, sale_price, fees, candidate_inventory_item_ids[]}]
  picks           JSONB,                        -- user-confirmed inventory_item_id per line
  committed_transaction_ids UUID[],
  agent_usage     JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Both tables follow standard `org_id` + RLS per D-002.

GCS layout:

```
card-inventory-uploads-{env}/
├── receipts/{org_id}/{draft_id}/{original_filename}
└── invoices/{org_id}/{draft_id}/{original_filename}
```

90-day lifecycle delete (kept longer than scans since they're tax-relevant source documents). Decision: see D-022 (TBD).

## MCP tool surface

Each tool maps to one backend HTTP call. All take `org_id` implicitly from the auth token.

| Tool | Maps to | Purpose |
|------|---------|---------|
| `inventory.search` | `GET /inventory?…` | Find active items by name/set/condition/location |
| `inventory.get` | `GET /inventory/{id}` | Full detail including location path |
| `inventory.update_status` | `PATCH /inventory/{id}/status` | active → sold/lost/destroyed |
| `acquisitions.create_draft` | `POST /acquisitions` w/ `status=draft` | Header row only |
| `acquisitions.add_line` | `POST /acquisitions/{id}/lines` | One line per call; agent loops |
| `acquisitions.commit` | `PATCH /acquisitions/{id}/status=committed` | Frontend-driven; agent never auto-commits |
| `listings.create` | `POST /listings` | (Bonus, used by ad-hoc Claude sessions) |
| `transactions.create` | `POST /transactions` | Links inventory_item + sale info |
| `catalog.search_printing` | `GET /catalog/printings?q=…` | Resolves name+set → printing_id |
| `catalog.search_product` | `GET /catalog/products?q=…` | Sealed SKUs (booster boxes, decks) |
| `market.price_snapshot` | `GET /market/price?printing_id=…&at=…` | Calls market-tracker / EV API; returns price + source |

The agent **never commits** acquisitions or transactions directly. It only drafts. The user's confirm-click in the frontend is the commit boundary.

## Flow A: Receipt → Purchase Order

```
1. User drops receipt.pdf onto Acquisitions page.
2. Frontend POSTs multipart to /ingest/receipt → backend stores in GCS,
   inserts acquisition_drafts row (status=parsing), returns draft_id.
3. Frontend opens WebSocket / polls /ingest/receipt/{draft_id}.
4. Backend agent runner:
     - Loads file from GCS as base64.
     - Starts Anthropic conversation with Sonnet 4.6, MCP tools attached.
     - System prompt: "Extract every purchased line item from this receipt.
       For each line: resolve to a printing_id via catalog.search_printing
       (or product_id via catalog.search_product for sealed). Look up the
       TCGPlayer market price at the receipt's date via market.price_snapshot.
       Call acquisitions.create_draft then acquisitions.add_line for each
       resolved line. For unresolvable lines, add a line with needs_review=true
       and your best guess in the notes field. Do NOT call commit."
     - Persists draft_payload + agent_notes + token usage on completion.
     - Flips status → ready (or failed).
5. Frontend renders editable acquisition: line items, costs, market snapshots,
   any needs_review flags surfaced inline.
6. User edits/confirms → POST /acquisitions/{id}/commit → status=committed,
   inventory_items rows created via existing acquisition-commit logic.
```

**Open question:** sealed-product line items must resolve to `products` rows, not `printings`. The agent needs to distinguish "1x Strixhaven Commander Deck" from "1x Sol Ring". Heuristic: try `catalog.search_product` first; fall back to `catalog.search_printing`. The two tools return different shapes so the agent picks correctly.

## Flow B: Invoice → Mark Sold

```
1. User drops invoice.pdf onto Sales page (new).
2. Frontend POSTs to /ingest/invoice → GCS + sale_drafts row.
3. Backend agent runner:
     - Loads file.
     - System prompt: "Extract buyer, channel, sale date, fees, and each line
       (card/sealed sold, condition, qty, per-unit sale price). For each line:
       resolve to printing_id, then call inventory.search filtered to
       status=active and matching printing_id/condition/finish. Return all
       candidate inventory_item_ids with their location paths. Do NOT call
       transactions.create — only draft."
     - Writes line_drafts JSON with candidate_inventory_item_ids per line.
     - Flips status → needs_picks.
4. Frontend renders a fulfillment picker:
     "Sol Ring NM — found 3 copies:
        ☐ Office → Box 3 → Binder A → Slot 12  (acquired 2026-01-04, cost $1.20)
        ☐ Office → Box 3 → Binder A → Slot 47  (acquired 2026-03-11, cost $1.55)
        ☐ Office → Box 5 → Loose             (acquired 2026-04-22, cost $1.80)"
   Default selection: oldest acquisition (FIFO). User adjusts → confirms.
5. POST /ingest/invoice/{id}/commit with picks → backend creates one
   transactions row per line, flips inventory_items to sold, captures
   sale_price/fees/channel/occurred_at from invoice_meta.
```

**Ambiguity is the hard part.** Picker UX must make FIFO the default but never auto-commit when ≥2 candidates exist. Single-candidate lines get a one-click confirm-all.

## Agent runner — implementation notes

Single Go package `internal/agent/`. Uses `github.com/anthropics/anthropic-sdk-go` with tool use loop. MCP integration: spawn `card-inventory-mcp` as a child process at backend startup, hold the stdio handle, multiplex per-run. Tool schemas pulled from the MCP server's `list_tools` response, passed to Anthropic API as the `tools` parameter — Anthropic SDK and MCP tool schemas are the same JSON Schema shape.

Per-run budget cap (env var `AGENT_MAX_TOKENS_PER_RUN`, default 100k) prevents runaway loops on pathological inputs.

All agent traces persisted to a `agent_runs` table for debugging:

```sql
CREATE TABLE agent_runs (
  id            UUID PRIMARY KEY,
  org_id        UUID NOT NULL,
  draft_kind    TEXT NOT NULL,        -- 'receipt' | 'invoice'
  draft_id      UUID NOT NULL,
  model         TEXT NOT NULL,        -- claude-sonnet-4-6
  messages      JSONB NOT NULL,       -- full conversation incl. tool calls/results
  input_tokens  INT,
  output_tokens INT,
  cost_usd      NUMERIC(10,4),
  started_at    TIMESTAMPTZ NOT NULL,
  finished_at   TIMESTAMPTZ,
  error         TEXT
);
```

Use Anthropic prompt caching on the system prompt + tool schemas (they're identical across runs). Cache hit reduces input-token cost by 90% after first run.

## Security / cost guardrails

- `ANTHROPIC_API_KEY` lives in backend env only.
- Per-org daily spend cap (env: `AGENT_DAILY_USD_CAP`, default $10). Enforced before each run by summing `agent_runs.cost_usd` for the org over last 24h.
- MCP server only listens on stdio (or `127.0.0.1:PORT` if HTTP transport is needed for debugging). Never exposed to the public internet.
- Agent commits nothing directly — all writes that mutate inventory state go through user confirmation.

## Open decisions (file as D-022+ in `DECISIONS.md`)

- **D-022:** Upload retention (90d default, but receipts are tax records — should this be 7yr cold-storage tier?)
- **D-023:** When a line is unresolvable, do we still persist it to the draft (with `needs_review`) or fail the whole draft? Default: persist; user can delete or edit before commit.
- **D-024:** Should the agent be allowed to read pop-report / grading data when an invoice line is for a graded slab? Adds complexity; v0.3.5 says no, raw market only.
- **D-025:** MCP transport — stdio (simpler) vs localhost HTTP (easier to debug with MCP Inspector). Default: stdio in prod, HTTP behind a feature flag for local dev.

## Out of scope for v0.3.5

- Automatic commit (always user-gated)
- Multi-receipt / multi-invoice batch upload
- Re-ingesting historical receipts/invoices
- Anthropic key per-org storage (deferred until SaaS multi-user lands)
- Browser-hosted agent variant
