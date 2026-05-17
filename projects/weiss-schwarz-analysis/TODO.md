# Weiss Schwarz Analysis — TODO

> **Checkout protocol:** see [`agents/README.md`](agents/README.md). Change `[ ]` → `[~claimed: agent-id YYYY-MM-DD]` in a single-file commit before working.
>
> **Task IDs are stable.** Never renumber. New tasks get the next free W-ID.
>
> **Status legend:** `[ ]` open · `[~]` claimed/in-progress · `[x]` done · `[!]` blocked · `[-]` cancelled

---

## 1. Repo & Infrastructure

- [x] W-001 Create `FG-CollectLabs/ws-set-analysis` GitHub repo  (commit: 415f9d4)
- [x] W-002 Initialize directory structure: `blog/`, `agents/`, `mcp/`, `seed-data/`  (commit: 415f9d4)
- [x] W-003 Scaffold Hugo site in `blog/` with a readable theme (PaperMod or similar)  (commit: 415f9d4)
- [x] W-004 Configure Hugo: `baseURL`, `languageCode`, section `sets/`, taxonomies (`recommendation`, `stage`, `ip`)  (commit: 415f9d4)
- [x] W-005 Set up GitHub Actions: Hugo build → deploy to GitHub Pages on push to `main`  (commit: 415f9d4)
- [x] W-006 Write `CLAUDE.md` for the repo with conventions (Python venv, Hugo build command, agent entry points)  (commit: 415f9d4)
- [x] W-007 Set up Python virtual environment spec (`pyproject.toml` or `requirements.txt`): `anthropic`, `httpx`, `requests`, `beautifulsoup4`, `mcp`  (commit: 415f9d4)

## 2. MCP Server — `mcp-jikan`

- [x] W-020 Scaffold `mcp/jikan/server.py` using the MCP Python SDK  (commit: 415f9d4)
- [x] W-021 Implement `get_anime(mal_id: int)` tool — fetches from `api.jikan.moe/v4/anime/{id}`; returns rank, score, members, favorites, popularity, status, episodes  (commit: 415f9d4)
- [x] W-022 Implement `get_manga(mal_id: int)` tool — same shape for manga  (commit: 415f9d4)
- [x] W-023 Implement `search_anime(query: str)` and `search_manga(query: str)` tools  (commit: 415f9d4)
- [x] W-024 Add 400ms inter-request sleep to respect Jikan rate limits  (commit: 415f9d4)
- [-] W-025 Write `mcp/jikan/README.md`: how to run locally, tool list, example output — usage docs in CLAUDE.md instead
- [x] W-026 Test: fetch RE:Zero anime (id=31240) and RE:Zero manga (id=74697) — validate output shape  (run: 2026-05-10, results in debug JSON)

## 3. MCP Server — `mcp-yuyutei`

- [x] W-040 Research Yuyutei URL structure for WS set listings  (commit: 415f9d4)
- [x] W-041 Scaffold `mcp/yuyutei/server.py`  (commit: 415f9d4)
- [x] W-042 Implement `search_set(query: str)` — scrape set listing page, return set names + IDs  (commit: 415f9d4)
- [x] W-043 Implement `get_set_cards(set_id: str)` — scrape card listing for a set; return rarity, name, buy price, sell price  (commit: 415f9d4)
- [x] W-044 Implement `get_set_summary(set_id: str)` — compute rarity breakdown, top-10 by price, EV per box; exclude AGR rarities from EV  (commit: 415f9d4)
- [x] W-045 Add 24h file cache: write JSON to `seed-data/jp-sets/<set_id>.json`; skip re-scrape if fresh  (commit: 415f9d4)
- [-] W-046 Write `mcp/yuyutei/README.md` — usage docs in CLAUDE.md instead
- [x] W-047 Test: fetch Re:Zero Vol.3 JP set, validate card list and EV output  (run: 2026-05-10, results in seed-data/jp-sets/RZ_S116.json)

## 4. MCP Server — `mcp-ws-prices`

- [x] W-060 Research TCGPlayer URL structure — decided Playwright scrape (WD-009 resolved: Playwright)  (commit: 415f9d4)
- [x] W-061 Scaffold `mcp/ws-prices/server.py`  (commit: 415f9d4)
- [x] W-062 Implement `get_box_price(set_name: str)` — returns current sealed booster box market price on TCGPlayer  (commit: 415f9d4)
- [x] W-063 Implement `get_card_price(card_name: str, set_name: str)` — market, low, high prices  (commit: 415f9d4)
- [x] W-064 Implement `get_set_summary(set_name: str)` — top 10 cards by price per set, SP/SSP average  (commit: 415f9d4)
- [x] W-065 Add user-agent header + respectful rate limiting  (commit: 415f9d4)
- [-] W-066 Write `mcp/ws-prices/README.md` — usage docs in CLAUDE.md instead
- [x] W-067 Test: fetch current box prices for Re:Zero Vol.1 and Vol.2 EN sets  (run: 2026-05-10)

## 5. Seed Data — RE:Zero EN Sets

- [x] W-080 Research and input `seed-data/en-sets/rezero-vol1.json`  (commit: 415f9d4)
- [x] W-081 Research and input `seed-data/en-sets/rezero-vol2.json`  (commit: 415f9d4)
- [x] W-082 Research and input `seed-data/en-sets/rezero-memory-snow.json`  (commit: 415f9d4)
- [x] W-083 Research and input `seed-data/en-sets/rezero-frozen-bond.json`  (commit: 415f9d4)
- [x] W-084 Create `agents/sets/rezero-vol3.json` — set config file (MAL IDs, EN set list, JP set references)  (commit: 415f9d4)
- [x] W-085 Identify Yuyutei set codes for all 5 JP RE:Zero sets (Vol.1-3, Memory Snow, Frozen Bond) — RZ/S46, RZ/S55, RZ/S68, RZ/SE35, RZ/S116  (commit: 415f9d4)

## 6. Analysis Agent — Core

- [x] W-100 Scaffold `agents/preorder/run.py`: CLI entry point, loads set config, orchestrates sub-agents  (commit: 415f9d4)
- [x] W-101 Implement `agents/preorder/ip_strength.py`: call mcp-jikan tools, compute IP score, handle unranked fallback  (commit: 415f9d4)
- [x] W-102 Implement `agents/preorder/en_historical.py`: load seed data, call mcp-ws-prices for current prices, compute % change and elapsed time  (commit: 415f9d4)
- [x] W-103 Implement `agents/preorder/jp_set_analysis.py`: call mcp-yuyutei, process full JP card list, compute EV excluding AGR  (commit: 415f9d4)
- [x] W-104 Implement `agents/preorder/synthesis.py`: apply V1 recommendation heuristics, produce structured recommendation dict  (commit: 415f9d4)
- [x] W-105 Implement `agents/preorder/post_generator.py`: render Hugo-compatible markdown with front matter  (commit: 415f9d4)
- [-] W-106 Write `agents/preorder/README.md` — usage docs in CLAUDE.md instead
- [x] W-107 Test end-to-end dry run: does it produce a valid Hugo markdown file?  (run: 2026-05-10 ✓)

## 7. First Analysis — RE:Zero Vol.3

- [x] W-120 Run preorder analysis agent: `python agents/preorder/run.py rezero-vol3`  (run: 2026-05-10)
- [x] W-121 Review generated post in `blog/content/sets/rezero-vol3/preorder.md`  (done: 2026-05-10)
- [ ] W-122 Manual edit pass: verify all data points are accurate, add any commentary the agent missed
- [x] W-123 Commit + push post; verify Hugo builds and renders correctly on GitHub Pages  (live: https://fg-collectlabs.github.io/ws-set-analysis/)
- [ ] W-124 Post-run retrospective: what data was missing? what needed manual correction? → file issues for agent improvements

## 10. Competitive Meta — weissteatime Integration

> Source: `weissteatime.com/category/deck-lists/tournament-decks/`
> Decision: WD-010 (resolved 2026-05-17)

- [ ] W-200 Scaffold `mcp/weissteatime/server.py` using MCP Python SDK
- [ ] W-201 Implement `get_tournament_index()` — scrape tournament deck category listing; return all posts with title, event type (Worlds/BCS/BSF), date range, URL
- [ ] W-202 Implement `get_event_meta(url: str)` — scrape a single event masterpost; parse per-set-code: field %, top-cut appearances, first-place count, event size
- [ ] W-203 Add 7-day file cache for event results: write to `seed-data/competitive/<event-slug>.json` with `cached_at`; re-use if fresh
- [ ] W-204 Implement `get_set_competitive_history(set_codes: list[str])` — aggregate across all cached events; return per-season field %, conversion rate, trend
- [ ] W-205 Write `agents/preorder/competitive_meta.py` sub-agent:
  - Calls `get_tournament_index()` + `get_set_competitive_history(config.competitive_set_codes)`
  - Classifies tier: `high` / `mid-high` / `mid` / `low` / `none` per ARCHITECTURE.md criteria
  - Detects trend: rising / stable / falling (YoY field % delta)
  - Flags "missing piece" when tier=`mid` and conversion_rate ≥ 15%
  - Returns structured dict: `{ tier, trend, field_pct_by_season, top_cut_count, missing_piece: bool, narrative: str }`
- [ ] W-206 Add `competitive_set_codes: list[str]` to set config schema (`agents/sets/*.json`); backfill for rezero-vol3 with `["RZ"]`
- [ ] W-207 Wire `competitive_meta.py` into `run.py` orchestration (after jp_set_analysis, before synthesis)
- [ ] W-208 Update `synthesis.py` to apply competitive tier modifier: `high` → +1 tier; `low`/`none` → −1 tier; others → neutral; append competitive narrative to synthesis output
- [ ] W-209 Update `post_generator.py` Competitive Standing section: render season-by-season table, trend badge, and powercreep/missing-piece narrative from competitive_meta output
- [ ] W-210 Test: run competitive_meta for OSK (Oshi no Ko) and verify `high` tier + powercreep narrative; run for RZ and classify
- [ ] W-211 Seed competitive cache by running get_tournament_index + get_event_meta across all Worlds/BCS/BSF posts back to BSF 2023 (6 events)

## 8. Refinement (post first analysis)

- [ ] W-140 Fine-tune recommendation heuristics based on retrospective (W-124)
- [ ] W-141 Add additional EN WS sets beyond RE:Zero as test cases (run analysis, check output quality)
- [ ] W-142 Decide and implement WD-008 (Google Trends for unranked IPs)
- [ ] W-143 Add `30d` stage runner: re-pull prices at 30 days post-release, update recommendation signal
- [ ] W-144 Build "accuracy tracker" Hugo page: table of past recommendations vs actual price movement
- [ ] W-145 Research automating pull-rate data from Bushiroad EN product pages (replace manual seed data)

## 9. Blog Polish

- [ ] W-160 Design set listing page: thumbnail image + IP name + recommendation badge + stage indicators
- [ ] W-161 Add recommendation badge styling (CSS or Hugo shortcode): color-coded strong-buy/buy/wait/pass
- [ ] W-162 Mobile-readable layout (WS is a mobile-adjacent hobby)
- [ ] W-163 Add "methodology" static page explaining how analysis works
- [ ] W-164 OG image / social preview for posts (optional)

---

## Parking lot

- Automated weekly price refresh jobs for post-release stages
- Discord webhook notification when a new analysis is published
- Multi-IP comparison page ("which set should I buy this month?")
- Integration with market-tracker-backend for EN card price history (long term)
- Buylist / sell signal: "now is the time to sell your Re:Zero boxes" post type
