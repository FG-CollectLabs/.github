# Checkpoint: Commander Deck Break Workspace

**Date:** 2026-05-19
**Session:** #2 — full-page workspace implemented
**Project:** card-inventory (backend + frontend), with ev-calculator dependency
**Status:** BreakWorkspace component shipped. TypeScript clean. Ready for local smoke-test.

---

## Problem the user is solving

Current "Break" flow in card-inventory has two pain points:

1. **Wrong UX surface** — Break opens as a small right-side panel. User wants this to be a majority-of-window workspace because breaking a Commander deck (or a box) is a long, focused operation.
2. **Wrong data assumption** — For a precon Commander deck (e.g. TMNT Commander), the current flow asks for a CSV import with empty cost rows. The decklist is *already known* — the app should auto-expand the precon into its 100 well-defined singles, not make the user provide them.

User's vision for the full workflow:
- Break a precon → auto-populate the 100 singles.
- Define persistent bins (1, 2, 3, 4, 5, ...) that are reused/recycled across operations (NOT ephemeral per-break).
- Drop scanned card images onto a bin in the UI → app identifies the card from the remaining-singles list and assigns it to that bin.

---

## Architecture decisions (settled)

### 1. Decklist data source

Decklists live in **`FG-CollectLabs/ev-calculator/data/decks/<set_code>/<deck-slug>.yaml`**.

- `GET /v1/decks/{key}` endpoint already exists in ev-calculator (`cmd/api/main.go` line 141, no auth)
- Frontend calls it via `fetchEVDeck(deckKey)` in `api.ts`
- TMNT deck key: `tmc-commander-turtle-power`

### 2. Bin model

"Bins" are the existing `locations` table (kind='bin'). No separate `bins` table was needed.
- `location_id` is already on `inventory_items`
- `createLocation(cfg, { name, kind: "bin" })` API already works

### 3. Break workspace UX

Answers given by user in session 2:
- **Editable before confirm**: YES — user can add/remove/edit cards in the center before confirming
- **Scan drop-zone**: Behind a flag / placeholder for now (center column is the editable card list)

Three-column layout:
- **Left rail** (220px) — locations list with per-bin card count, active bin indicator, "+ New" inline form
- **Center** — editable card rows (name, catalog key, condition, cost, location, platform), empty state prompts right rail
- **Right rail** (280px) — deck manifest checklist with covered/remaining counters; click to add one copy; "Add all" button for bulk

---

## What was done in session 2

All three implementation steps complete:

### 1. `BreakWorkspace.tsx` created (new file)
`c:\Users\nguye\VSCode\FG-CollectLabs\card-inventory-frontend\src\views\BreakWorkspace.tsx`

- Three-column layout (left bins rail, center editable rows, right manifest checklist)
- Fetches locations and manifest in parallel on mount
- Left rail: click to set active bin, +New bin inline form (creates via API), per-bin card count badge
- Right rail: each component shows covered/total indicator; click adds one row to center; "Add all" adds all remaining; greyed when fully covered
- Center: editable grid rows (name, catalog key, condition, cost, location dropdown, platform); +Add row; ✕ to remove
- Submit calls `breakInventoryItem` → `onComplete(consumed, singles)`

### 2. `App.tsx` updated
- Added `InventoryItem` to type imports
- Added `breakTarget: InventoryItem | null` state
- When `breakTarget` is set, renders `<BreakWorkspace>` instead of the normal view (takes over full main area)
- `Inventory` now receives `onStartBreak={setBreakTarget}`

### 3. `Inventory.tsx` updated
- Added `onStartBreak?: (item: InventoryItem) => void` prop
- Break button: calls `onStartBreak(selected)` when provided, falls back to old inline BreakForm if not

TypeScript check: **clean** (`npx tsc --noEmit` exits 0).

---

## What's NOT done yet (next session pick-up)

1. **Scan drop-zone** — center column stub only; no card-identifier integration yet. When ready:
   - Call `POST /v1/scan/identify` (ev-calculator proxy) with image + restrict to remaining items
   - Auto-match candidate → move matched card from right rail to confirmed in center
   - The ev-calculator already proxies to card-identifier-backend

2. **Deck YAML audit** — not every deck in `ev-calculator/data/decks/` has been audited against canonical Scryfall decklists. Create a separate task for this sweep.

3. **Local smoke-test** — workspace needs to be run against a live backend with a TMNT sealed item in inventory to verify:
   - Manifest loads from ev-api
   - Bin creation works
   - Break confirm creates correct singles
   - `onComplete` routes back to inventory view cleanly

---

## Relevant paths

| Path | Purpose |
|------|---------|
| `card-inventory-frontend/src/views/BreakWorkspace.tsx` | NEW — full-page workspace |
| `card-inventory-frontend/src/App.tsx` | breakTarget state + BreakWorkspace render |
| `card-inventory-frontend/src/views/Inventory.tsx` | onStartBreak prop + break button redirect |
| `ev-calculator/cmd/api/main.go:141` | `GET /v1/decks/{key}` endpoint |
| `ev-calculator/data/decks/tmc/turtle-power.yaml` | TMNT deck manifest (657865 product ID) |
| `card-inventory-backend/internal/inventory/handler.go` | Break handler: `POST /items/{id}/break` |
