# Checkpoint: Commander Deck Break Workspace

**Date:** 2026-05-19
**Session:** #3 — drag-drop scan + non-precon manifest shipped
**Project:** card-inventory-frontend (deploys to inventory.futuregadgetlabs.com)
**Status:** Workspace + scan flow deployed. Awaiting real-world smoke test.

---

## What this checkpoint is

A persistent break workspace for sealed-product card breaks. Replaces
the cramped right-panel BreakForm with a full-window three-column UX
that supports drag-drop image identification, persistent bins, and a
deck-manifest checklist that drives toward "all cards accounted for."

User vision (from session 1):
- Break a precon → auto-populate expected 100 singles from ev-calculator
- Persistent bins (reused across operations, not per-break scratch)
- Drop scanned card images onto a bin → identify and check off from manifest
- For non-precon: same UX but right rail accumulates as you go

---

## State of play (what's deployed, what isn't)

### Deployed to inventory.futuregadgetlabs.com

**Session 1 — endpoint:** `GET /v1/decks/{key}` on ev-calculator
([cmd/api/main.go:141](../../ev-calculator/cmd/api/main.go)). Returns
component list + image. No auth.

**Session 2 — full-page workspace:**
[card-inventory-frontend/src/views/BreakWorkspace.tsx](../../card-inventory-frontend/src/views/BreakWorkspace.tsx)
- Three-column layout: bins | rows | manifest
- Left rail: locations list with per-bin row count, "+ New" inline form (uses existing `locations` table, kind='bin')
- Center: editable row grid (name, catalog key, condition, cost, location, platform)
- Right rail: deck manifest with covered/remaining counter, click-to-add, "Add all"
- Triggered from Inventory.tsx "Break open" button → App.tsx renders BreakWorkspace in place of normal view

**Session 3 — drag-drop scan:**
- Scan controls row in center pane: toggle "1 image = 1 card" vs "pairs = front + back"
- Pair mode: dropped files alternate as front/back across drops; pendingFront state held between drops, with a cancel link
- Drop zone disabled when no bin selected (forces bin pick first)
- Auto-add for confidence ≥ 0.85 with manifest name-match (exact, then substring); otherwise inline review queue with candidate buttons
- Object URLs cleaned up on dismiss/unmount
- Non-precon (no manifest) path: right rail switches to grouped-by-name "Added cards" tally

### Not done — picks for next session

1. **Smoke-test on TMNT Commander.** User has the workspace + scan deployed but hasn't actually broken a deck end-to-end yet. Risks to watch:
   - Does the identification API actually return useful results for TMNT cards? (The card-identifier service is set-restricted via `restrict_set` form param — we're not sending one.)
   - Does the name-match logic work? TMNT names like "Heroes in a Half Shell" should match exactly, but watch for `//` split cards (e.g. "Double Jump // Flying Kick") and the `name` field having "the Brains" suffixes that may or may not match scryfall.
   - Confidence threshold of 0.85 is a guess — may need to lower to 0.7 if the identifier is conservative.

2. **Back image upload.** Back images are accepted into `ScanItem.back` but never sent anywhere. The ev-api exposes `POST /v1/scan/back` (with `scan_id` + image) which proxies to card-identifier-backend. Wiring up:
   - capture `scan_id` from `identifyCard` result (already returned, just not stored on ScanItem)
   - POST the back image after a pair commits
   - Decide where the resulting image URL is persisted — currently card-inventory-backend `inventory_items` has no image columns. Probably a separate `inventory_item_images` table or just stash in `notes` JSON.

3. **Pass `restrict_set` to identifyCard.** When a manifest exists, we know the set code(s) — passing them to the identifier would dramatically improve accuracy. Need to extend `identifyCard(image, restrictSet?)` signature in api.ts.

4. **Deck YAML audit sweep.** Not every deck in `ev-calculator/data/decks/` has been audited against canonical Scryfall decklists. The TMNT deck has 5 `note: not in inventory CSV — verify ID` lines. A separate task: walk every YAML, fetch Scryfall set lists, flag mismatches.

5. **Card-identifier restrict by remaining manifest.** Per session 1 checkpoint, the dream is "search space scoped to the remaining-to-find list from this break only" for much higher accuracy. Card-identifier-backend would need a new param (`candidate_printing_ids: [...]`) — not yet implemented on the service side. Lower priority than `restrict_set`.

---

## Decisions logged (so the next agent doesn't re-litigate them)

- **Bins use existing `locations` table** with `kind='bin'`. No new `bins` table.
- **Edit-before-confirm** is the precon flow (user can add/remove/edit rows before submitting the break).
- **Pair mode** uses a single drop zone with sequential pairing (front then back across drops), not two side-by-side zones.
- **Auto-accept confidence threshold = 0.85**. Below that, inline review queue.
- **App.tsx, not React Router.** Workspace is rendered conditionally via `breakTarget` state in App.tsx; no URL-based routing.

---

## Relevant paths

| Path | Purpose |
|------|---------|
| `card-inventory-frontend/src/views/BreakWorkspace.tsx` | The workspace |
| `card-inventory-frontend/src/App.tsx` | `breakTarget` state, renders workspace |
| `card-inventory-frontend/src/views/Inventory.tsx` | `onStartBreak` prop, triggers workspace |
| `card-inventory-frontend/src/api.ts:418` | `fetchEVDeck(deckKey)` |
| `card-inventory-frontend/src/api.ts:426` | `identifyCard(image)` — only sends front, no `restrict_set` yet |
| `ev-calculator/cmd/api/main.go:141` | `GET /v1/decks/{key}` |
| `ev-calculator/cmd/api/main.go:222` | `POST /v1/scan/identify` proxy → card-identifier |
| `ev-calculator/cmd/api/main.go:225` | `POST /v1/scan/back` proxy (unused by frontend) |
| `ev-calculator/data/decks/tmc/turtle-power.yaml` | TMNT Commander manifest (5 IDs need verification) |
| `card-inventory-backend/internal/inventory/handler.go` | `POST /items/{id}/break` consumer |

---

## How to pick up next session

1. Ask user how the TMNT break smoke-test went. If unrun, that's the first thing.
2. If identification accuracy was bad: add `restrict_set` param to `identifyCard` and pass `manifest.set_code` when available.
3. If accuracy was OK but back images are wanted: wire `/v1/scan/back` upload after pair commit. Decide image persistence strategy (new table vs notes JSON).
4. If the deck YAML mismatches showed up: schedule the audit sweep as its own task.
