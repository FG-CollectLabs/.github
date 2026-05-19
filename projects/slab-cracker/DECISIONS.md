# Slab Cracker — Open Decisions

## D-001 — Backend language / framework [RESOLVED 2026-05-19]

**Question**: Should the backend follow the `fg-collect-core` Go + pgx/sqlc pattern used by market-tracker and card-identifier?

**Resolution**: Yes. `slab-cracker-backend` scaffolded with Go 1.25, `net/http.ServeMux`, `pgx/v5` connection pool, sqlc config for later codegen. Module path `github.com/FG-CollectLabs/slab-cracker-backend`.

---

## D-002 — Where does the backend sit in the data flow? [RESOLVED 2026-05-19]

**Question**: Does the backend replace the extension's scraping, or does the extension continue to scrape and POST results to the backend?

**Resolution**: Option A — extension scrapes, POSTs to backend. Captchas on PSA/CGC make full automation impractical; the human element (one-click "Open in Slab Cracker") solves the captcha while the extension makes the workflow seamless. Backend is a persistence + query layer only.

---

## D-003 — How to deduplicate analyses on the same cert? [RESOLVED 2026-05-19]

**Question**: If a cert has already been analyzed, what should happen when the user loads it again?

**Resolution**: Option B — store every analysis, show history. Critical use case: when a regrade returns the same grade (e.g. PSA 9 → PSA 9), the user needs both measurements side by side to decide whether to resubmit or give up.

---

## D-004 — Card catalog normalization strategy [RESOLVED 2026-05-19]

**Question**: How do we group many different certs that are all the same card (e.g., all PSA 9 Base Set Pikachu)?

**Resolution**: Don't build a separate `card_catalog` table. Instead add `display_key TEXT` (nullable) to `certs` and reuse `market-tracker-backend.cards.display_key` as the canonical identifier. The frontend calls both APIs independently and merges client-side. This also unlocks the crack signal — market tracker already has PSA9/PSA10/CGC10 prices + gem rates via `/v1/cards/{display_key}/graded`, so the frontend can combine slab cracker's centering ceiling with market tracker's regrade EV math.
