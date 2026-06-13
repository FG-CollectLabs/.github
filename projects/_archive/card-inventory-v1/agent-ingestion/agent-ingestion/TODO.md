# Agent Ingestion — TODO

Granular task list for v0.3.5. Status markers: `[ ]` open · `[~]` in progress · `[x]` done.

## T-AI-001 — Scaffold `card-inventory-mcp` repo
- [x] New repo `FG-CollectLabs/card-inventory-mcp` (TypeScript, `@modelcontextprotocol/sdk`)
- [x] `package.json`, `tsconfig.json`, `README.md`
- [x] Stdio transport baseline; tools scaffolded
- [ ] CI: typecheck + lint on push

> **Architecture note:** The backend agent runner (`internal/ingest/agent.go`) calls the Anthropic API directly via HTTP rather than routing through the MCP server. The MCP server (`card-inventory-mcp`) exists as a standalone tool for ad-hoc Claude sessions but is not in the hot path. This is simpler and avoids the stdio subprocess lifecycle.

## T-AI-002 — MCP tools: read-only catalog + inventory
- [x] `catalog.search_printing` (via agent's direct DB search — `searchInventoryDB`)
- [x] `inventory.search` (printing_id, condition, status, location — used by invoice agent)
- [x] `market.price_snapshot` — EV deck catalog fetched via `ResolveSealedProducts`; receipt review UI shows EV per sealed line
- [-] `inventory.get` (full detail w/ location path) — not needed in current flow
- [-] Integration test — deferred

## T-AI-003 — MCP tools: write surface for acquisitions
- [x] `acquisitions.create_draft` — agent drafts into `acquisition_drafts` table
- [x] `acquisitions.add_line` — lines stored as `draft_payload` JSON
- [x] Backend support for `acquisition_drafts` table with `status=parsing|ready|committed|discarded`

## T-AI-004 — MCP tools: write surface for sales
- [x] `transactions.create` — via `POST /ingest/invoices/{id}/commit` after user picks
- [x] `inventory.update_status` — items flipped to `sold` on invoice commit

## T-AI-005 — Backend: ingest tables + migrations
- [x] Migration `0013_agent_ingestion.sql`: `acquisition_drafts`, `sale_drafts`, `agent_runs`
- [x] Migration `0018_acquisition_drafts_fk.sql`: FK ON DELETE SET NULL fix
- [x] Raw pgx queries (no sqlc — draft_payload is untyped JSONB)
- [x] `org_id` discriminator on all three tables

## T-AI-006 — Backend: GCS uploads bucket
- [-] **Deferred** — files stored as `bytea` in `acquisition_drafts.file_data` / `sale_drafts.file_data`. GCS upload is a future optimization if files grow large.

## T-AI-007 — Backend: agent runner package
- [x] `internal/ingest/agent.go` — Anthropic API called directly via raw HTTP (no SDK dep)
- [x] Receipt: single-shot Haiku parse → `ReceiptDraft` JSON
- [x] Invoice: multi-turn Sonnet 4.6 tool-use loop (up to 12 rounds) with `search_inventory` tool
- [x] Per-run token budget cap (`AGENT_MAX_TOKENS_PER_RUN`, default 16k)
- [x] Agent run trace + token usage persisted to `agent_runs`
- [x] 5-minute in-memory cache for EV deck catalog
- [-] Per-org 24h spend cap — deferred (single-tenant for now)
- [-] Prompt caching — deferred

## T-AI-008 — Backend: receipt ingest endpoint
- [x] `POST /api/v1/orgs/{org_id}/ingest/receipt` — multipart → DB → agent → draft
- [x] `GET /api/v1/orgs/{org_id}/ingest/receipts` — list drafts
- [x] `GET /api/v1/orgs/{org_id}/ingest/receipts/{id}` — get draft
- [x] `POST /api/v1/orgs/{org_id}/ingest/receipts/{id}/commit` — draft → acquisition + inventory_items
- [x] `POST /api/v1/orgs/{org_id}/ingest/receipts/{id}/discard`
- [x] Sealed product `display_key` resolution via EV deck catalog
- [x] Tax + shipping overhead distributed proportionally across lines

## T-AI-009 — Backend: invoice ingest endpoint
- [x] `POST /api/v1/orgs/{org_id}/ingest/invoice`
- [x] `GET /api/v1/orgs/{org_id}/ingest/invoices` / `/{id}`
- [x] `POST /api/v1/orgs/{org_id}/ingest/invoices/{id}/commit` — picks map → transactions + items flipped to sold
- [x] `POST /api/v1/orgs/{org_id}/ingest/invoices/{id}/discard`
- [x] Agent searches inventory via `search_inventory` tool (ILIKE + condition filter, up to 10 candidates)
- [x] Candidates include full location path breadcrumb

## T-AI-010 — Frontend: receipt drop zone
- [x] Drop zone on Acquisitions page (drag-drop + click-to-browse, PDF/JPG/PNG/WEBP)
- [x] Inline editable draft review table (name, set, qty, unit cost, condition, sealed flag)
- [x] Inline catalog picker for unmatched sealed lines (search EV displays + drill into decks)
- [x] `needs_review` warning per line
- [x] EV column — shows market EV from EV API alongside cost; green if EV ≥ paid, amber if below
- [x] Confirm → commit; Discard → discards draft

## T-AI-011 — Frontend: invoice drop zone + fulfillment picker
- [x] Invoice panel under Transactions → "Invoice" tab
- [x] Drop zone + in-line processing (no polling — synchronous backend call)
- [x] Per-line `InvoiceLineCard` with radio picker for candidates
- [x] Candidates show name, condition, location path, cost basis, acquired date
- [x] FIFO default selection (first candidate = oldest acquisition)
- [x] Confirm → POST commit with picks; Discard → drop

## T-AI-012 — Frontend: agent run inspector (dev tool)
- [ ] Hidden `/dev/agent-runs/{id}` route — deferred, low priority

## T-AI-013 — Deploy
- [x] Backend deployed on LXC 111 (`philwin/card-inventory-backend:latest`, Watchtower-managed)
- [x] `ANTHROPIC_API_KEY` set in prod docker-compose on LXC 111
- [x] `EV_BASE_URL` defaults to `https://ev-api.futuregadgetlabs.com` (no override needed)
- [x] Migrations run via Goose on startup
- [x] Frontend dist deployed to LXC 111 nginx on 2026-05-31

## T-AI-014 — Decisions write-up
- [ ] Add D-022 / D-023 / D-024 / D-025 to `DECISIONS.md`
- [ ] Update `roadmap.md` v0.3.5 section with ✅ markers
