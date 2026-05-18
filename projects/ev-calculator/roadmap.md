# EV Calculator — Roadmap

> **Status legend:** `[ ]` open · `[~]` claimed/in-progress · `[x]` done · `[!]` blocked · `[-]` cancelled
>
> **Task IDs are stable.** Never renumber. New tasks get the next free ID.

---

## v0.1.0 — Shipped (2026-05-18)

- [x] EV-001 Firebase Google OAuth auth gate (production-enabled)
- [x] EV-002 YAML-backed deck data (`data/decks/<set>/`) — TCGPlayer product IDs audited via Scryfall
- [x] EV-003 Platform fee modeling — TCGPlayer / Manapool / eBay
- [x] EV-004 Per-deck and per-card market price breakdown; deck collapse/expand toggle
- [x] EV-005 Card scan identification (proxies card-identifier-backend)
- [x] EV-006 eBay File Exchange CSV export
- [x] EV-007 Image proxy for TCGPlayer CDN
- [x] EV-008 Swagger UI at `/docs`
- [x] EV-009 Production deploy: `ev-calculator.futuregadgetlabs.com` + `ev-api.futuregadgetlabs.com` (Cloudflare Tunnel)

---

## v0.2.0 — Market-Tracker Integration

**Depends on:** market-tracker-backend deployed + catalog seeded (see `projects/market-tracker/TODO.md` Phase 1–3)

- [ ] EV-010 Switch default price source from TCGCSV to market-tracker `/v1/prices/batch`
- [ ] EV-011 Extend market-tracker `PriceRow` to return `listing_count`, `units_sold_week`, `depth_to_plus_{10,25,50}_units` — fix is in `market-tracker-backend/internal/prices/handler.go`
- [ ] EV-012 Wire `sellthrough.Recommend` — currently always returns `Confidence="unknown"` pending EV-011
- [ ] EV-013 Add price source indicator in UI (shows DB snapshot vs live fetch + snapshot age)
- [ ] EV-014 Add "live fetch" button — forces fresh TCGCSV pull, bypasses DB cache
- [ ] EV-015 Surface eBay sold price alongside TCGPlayer/Manapool in the singles table

---

## v0.3.0 — Catalog Expansion

- [ ] EV-020 Add Bloomburrow Commander decks (`blc`) to `data/decks/`
- [ ] EV-021 Add Final Fantasy Commander decks (`ffc`) to `data/decks/`
- [ ] EV-022 Add remaining planned sets: `ltc`, `tmc`, `fic`, `lcc`, `tdc`, `eoc`
- [ ] EV-023 Seed all EV calculator sets into market-tracker catalog (pairs with market-tracker EV-010)
- [ ] EV-024 Admin endpoint or CLI to reload deck YAML without restarting (hot reload)

---

## v0.4.0 — UI & UX

- [ ] EV-030 Price history chart per card (pulls from market-tracker snapshots)
- [ ] EV-031 Manapool price column alongside TCGPlayer in singles table
- [ ] EV-032 Save selected platform + strategy to localStorage (persist across sessions)
- [ ] EV-033 Display (case) level page — aggregate EV across all decks in a case
- [ ] EV-034 Mobile layout pass — singles table is unusable on small screens

---

## Future / Cloud Migration

- [ ] EV-040 Move API from Proxmox homelab to Cloud Run (pairs with market-tracker cloud migration)
- [ ] EV-041 Keep frontend on GitHub Pages; update `VITE_API_URL` to Cloud Run URL
- [ ] EV-042 Nightly price refresh via Cloud Scheduler → market-tracker ingest → EV cache invalidation
