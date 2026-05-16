# AnonTCG Deal Analyzer — TODO

> **Task IDs are stable.** Never renumber. New tasks get the next free A-ID.
>
> **Status legend:** `[ ]` open · `[~]` claimed/in-progress · `[x]` done · `[!]` blocked · `[-]` cancelled

---

## 1. Foundation

- [x] A-001 Create `FG-CollectLabs/anontcg-deal-analyzer` GitHub repo
- [x] A-002 Initialize directory structure: `data/products/`, `mcp/`, `agents/`, `blog/`, `scripts/`
- [x] A-003 Write `requirements.txt` (mcp, httpx, playwright, anthropic, pyyaml)
- [x] A-004 Write `CLAUDE.md` with workflow and schema docs
- [x] A-005 Configure `.mcp.json` for Claude Code MCP integration

## 2. Product Catalog

- [x] A-010 Write YAML for all 45 AnonTCG subscription products (2026-05-12 snapshot)
  - Fixed price field: `anontcg_price_cents` (was `msrp_cents` on first file)
  - 42 active, 3 sold out
  - All 5 games: Pokémon, Weiss Schwarz, Yu-Gi-Oh!, Lorcana, One Piece
- [ ] A-011 Verify pack contents for all future/TBD products on release and update YAMLs
  - TBD products: ME02, ME03, June 2025 Premium, Collector Chest Q3 2025, Nov Kangaskhan, Venusaur, Summer 2025 Tin, Tin Q4 2025, SV09 Pre-release
- [ ] A-012 Fill in `pack_ev_cents` for well-known sets where EV is stable
  - Priority: SV03 Obsidian Flames, SV06 Twilight Masquerade, SWSH12 Silver Tempest, SV4.5 Paldean Fates
- [ ] A-013 Add `anontcg_shopify_handle` field to YAMLs for precise live-price matching
  - Currently matches by YAML key; Shopify handle may differ for some products
- [ ] A-014 Verify tin case unit counts (5107 = 12 per case assumption; confirm with distributor docs)

## 3. MCP Servers

- [x] A-020 `mcp/anontcg.py`: `list_anontcg_products` via Shopify JSON API
- [x] A-021 `mcp/anontcg.py`: `get_product_contents` reads YAML catalog
- [x] A-022 `mcp/anontcg.py`: `calculate_deal` with correct EV×units math and dual discount metrics
- [x] A-023 `mcp/anontcg.py`: `list_catalog_keys` tool for agent discovery
- [x] A-024 `mcp/tcgplayer.py`: `get_tcgplayer_sealed_price` via Playwright
- [x] A-025 `mcp/tcgplayer.py`: `get_pack_ev` via top-card heuristic
- [ ] A-026 Add `mcp/tcgplayer.py`: `get_promo_price(card_name)` tool for promo card lookups
  - Needed for accurate contents EV on collection products
- [ ] A-027 Improve TCGPlayer selector robustness (site layout changes break scraping)
  - Add fallback selectors; log which selector matched

## 4. Batch Scripts

- [x] A-030 `scripts/generate_dashboard.py` → `blog/static/deals.json`
  - Reads all YAMLs, merges live Shopify prices + cached TCGPlayer prices
  - Calculates all metrics, sorts by best discount, outputs JSON
- [x] A-031 `scripts/refresh_tcgplayer_prices.py` → `blog/static/tcgplayer-prices.json`
  - Playwright scraper for all products
  - `--key`, `--game`, `--set-price` flags
- [ ] A-032 Test end-to-end: run refresh_tcgplayer_prices → generate_dashboard → hugo serve
- [ ] A-033 Add `--dry-run` flag to generate_dashboard.py (print results without writing)

## 5. Dashboard UI

- [x] A-040 `blog/layouts/index.html`: dark-theme sortable table dashboard
  - Sort tabs: Best Discount, Sealed vs TCGPlayer, Contents EV Discount, Price ↑/↓
  - Filter: game, active-only, hide-unknown
  - Verdict badges: STRONG_BUY / BUY / NEUTRAL / PASS / UNKNOWN
  - Columns: Sub Price, Per Unit, TCGPlayer Per Unit, Sealed Discount %, Contents EV, Contents Discount %
- [ ] A-041 Add product detail modal or expandable row (show full pack list, promo details, notes)
- [ ] A-042 Add "last updated" freshness indicator with warning if deals.json >7 days old
- [ ] A-043 Deploy to GitHub Pages (add Hugo build + GH Pages action)
- [ ] A-044 Add TCGPlayer link column (clickable unit search link)

## 6. Agent

- [x] A-050 `agents/deal_analysis/run.py`: per-product analysis agent using MCP servers
- [ ] A-051 Update agent prompt to use new `calculate_deal` output fields (sealed_discount_pct, contents_discount_pct)
- [ ] A-052 Test agent on a product with good TCGPlayer data (e.g., SV06 ETB case)
- [ ] A-053 Add `--all` mode: run agent for all active products, write blog posts

## 7. First Run

- [ ] A-060 Run `scripts/refresh_tcgplayer_prices.py` for all active Pokémon products
- [ ] A-061 Run `scripts/generate_dashboard.py` and inspect output
- [ ] A-062 Check `hugo serve -s blog` — dashboard loads with real data
- [ ] A-063 Manually set prices for any products where scraping returned no result
- [ ] A-064 Run deep agent analysis on top 3 deals (by sealed_discount_pct)

## 8. Ongoing Maintenance

- [ ] A-070 Weekly: re-run refresh_tcgplayer_prices + generate_dashboard
- [ ] A-071 When new products appear on AnonTCG: add YAML, refresh, regenerate
- [ ] A-072 When TBD products release: update pack contents in YAML, re-run
- [ ] A-073 Track verdict accuracy: when you buy a deal, log actual ROI vs predicted

---

## Parking lot

- Webhook / scheduled job to auto-refresh prices daily
- Email/Discord alert when a new STRONG_BUY appears
- Historical deal tracking (was this better last week?)
- Multi-subscription analysis (if buying N items, which N maximize total discount?)
- EV pull rate data from Limitless TCG or Pokémon official for more accurate pack EV
