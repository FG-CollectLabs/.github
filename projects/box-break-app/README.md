# Box Break App

Standalone scanner app for cataloging box breaks. Drop a folder of card scans — fronts and backs automatically identified, paired, and grouped by card. Exports a CSV with image URLs and quantities.

---

## Use cases

1. **Preconstructed deck break** — validate every card in the decklist is scanned and accounted for.
2. **Booster box break** — build the card list with quantities and scan images from scratch.

---

## User flow

1. (Optional) Enter the set code (e.g. `TMC`) to restrict identification to that set.
2. Drag-drop a folder of scanner images (or browse-select multiple).
3. App identifies each image concurrently (max 3 at a time):
   - **Front card** → pHash+OCR identify → auto-pair to card group
   - **Card back** → auto-paired with the immediately preceding front image
4. Review queue on the right; card groups build up on the left.
5. Manual assignment for low-confidence results.
6. Export CSV when done.

---

## Exported CSV format

| Column | Description |
| --- | --- |
| `card_name` | Full card name including variant suffix |
| `card_number` | Collector number (extracted from name if present) |
| `set_name` | Set name from TCGPlayer candidate |
| `tcgplayer_id` | TCGPlayer product ID |
| `quantity` | Number of copies identified |
| `front_image_urls` | Pipe-separated list of stored scan URLs (one per copy) |
| `back_image_urls` | Pipe-separated list of stored back scan URLs (empty if not scanned) |

Images are stored at `cards.futuregadgetlabs.com/scan-images/{scan_id}-front.jpg` by the card-identifier backend on every identify call. Backs are also stored under their own scan ID.

---

## Architecture

```
box-break-app (Vite · React 18 · TypeScript · GitHub Pages)
│
└─ identifies cards via ──► ev-api.futuregadgetlabs.com/v1/scan/identify
                            (card-identifier-backend, pHash + OCR)
```

No backend of its own. Pure frontend SPA.

---

## Card Inventory integration

Two integration paths planned for the inventory app:

### Path A — Drag-drop photos (existing flow)
User drags scan images directly into the eBay export scan modal. The same identification logic runs inline.

### Path B — Import box-break CSV
User runs the box break app first → gets a validated CSV with image URLs and quantities → drags that CSV into the inventory acquisition flow. The inventory app reads `card_name`, `tcgplayer_id`, `quantity`, `front_image_urls`, `back_image_urls` and creates acquisition line items with images pre-populated.

Path B is the preferred flow for large breaks — image assignment is pre-validated before inventory creation.

---

## Repo

`FG-CollectLabs/box-break-app` — GitHub Pages deployment at `fg-collectlabs.github.io/box-break-app/`

---

## Status

- [ ] Initial Vite/React/TS scaffold
- [ ] Image drop zone + concurrent identify pipeline
- [ ] Front/back auto-pairing (back = previous front's pair)
- [ ] Card grouping by TCGPlayer ID / name
- [ ] Manual assignment UI for medium/no-confidence results
- [ ] CSV export
- [ ] GH Actions deploy to GitHub Pages
- [ ] Inventory CSV import (Path B above)
