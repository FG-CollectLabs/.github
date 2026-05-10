# Weiss Schwarz Analysis — TODO

> **Checkout protocol:** see [`agents/README.md`](agents/README.md). Change `[ ]` → `[~claimed: agent-id YYYY-MM-DD]` in a single-file commit before working.
>
> **Task IDs are stable.** Never renumber. New tasks get the next free W-ID.
>
> **Status legend:** `[ ]` open · `[~]` claimed/in-progress · `[x]` done · `[!]` blocked · `[-]` cancelled

---

## 1. Repo & Infrastructure

- [ ] W-001 Create `FG-CollectLabs/ws-set-analysis` GitHub repo
- [ ] W-002 Initialize directory structure: `blog/`, `agents/`, `mcp/`, `seed-data/`
- [ ] W-003 Scaffold Hugo site in `blog/` with a readable theme (PaperMod or similar)
- [ ] W-004 Configure Hugo: `baseURL`, `languageCode`, section `sets/`, taxonomies (`recommendation`, `stage`, `ip`)
- [ ] W-005 Set up GitHub Actions: Hugo build → deploy to GitHub Pages on push to `main`
- [ ] W-006 Write `CLAUDE.md` for the repo with conventions (Python venv, Hugo build command, agent entry points)
- [ ] W-007 Set up Python virtual environment spec (`pyproject.toml` or `requirements.txt`): `anthropic`, `httpx`, `requests`, `beautifulsoup4`, `mcp`

## 2. MCP Server — `mcp-jikan`

- [ ] W-020 Scaffold `mcp/jikan/server.py` using the MCP Python SDK
- [ ] W-021 Implement `get_anime(mal_id: int)` tool — fetches from `api.jikan.moe/v4/anime/{id}`; returns rank, score, members, favorites, popularity, status, episodes
- [ ] W-022 Implement `get_manga(mal_id: int)` tool — same shape for manga
- [ ] W-023 Implement `search_anime(query: str)` and `search_manga(query: str)` tools
- [ ] W-024 Add 400ms inter-request sleep to respect Jikan rate limits
- [ ] W-025 Write `mcp/jikan/README.md`: how to run locally, tool list, example output
- [ ] W-026 Test: fetch RE:Zero anime (id=31240) and RE:Zero manga (id=74697) — validate output shape

## 3. MCP Server — `mcp-yuyutei`

- [ ] W-040 Research Yuyutei URL structure for WS set listings (https://yuyu-tei.jp/game_ws/sell/list.php)
- [ ] W-041 Scaffold `mcp/yuyutei/server.py`
- [ ] W-042 Implement `search_set(query: str)` — scrape set listing page, return set names + IDs
- [ ] W-043 Implement `get_set_cards(set_id: str)` — scrape card listing for a set; return rarity, name, buy price, sell price
- [ ] W-044 Implement `get_set_summary(set_id: str)` — compute rarity breakdown, top-10 by price, EV per box; exclude AGR rarities from EV
- [ ] W-045 Add 24h file cache: write JSON to `seed-data/jp-sets/<set_id>.json`; skip re-scrape if fresh
- [ ] W-046 Write `mcp/yuyutei/README.md`
- [ ] W-047 Test: fetch Re:Zero Vol.3 JP set, validate card list and EV output

## 4. MCP Server — `mcp-ws-prices`

- [ ] W-060 Research TCGPlayer URL structure for WS card/box prices; identify if public price endpoints are usable (decide WD-009)
- [ ] W-061 Scaffold `mcp/ws-prices/server.py`
- [ ] W-062 Implement `get_box_price(set_name: str)` — returns current sealed booster box market price on TCGPlayer
- [ ] W-063 Implement `get_card_price(card_name: str, set_name: str)` — market, low, high prices
- [ ] W-064 Implement `get_set_summary(set_name: str)` — top 10 cards by price per set, SP/SSP average
- [ ] W-065 Add user-agent header + respectful rate limiting
- [ ] W-066 Write `mcp/ws-prices/README.md`
- [ ] W-067 Test: fetch current box prices for Re:Zero Vol.1 and Vol.2 EN sets

## 5. Seed Data — RE:Zero EN Sets

- [ ] W-080 Research and input `seed-data/en-sets/rezero-vol1.json`: release date (2018-07-27), preorder price, pull rates (SP, SSP, RRR, RR, R), competitive standing
- [ ] W-081 Research and input `seed-data/en-sets/rezero-vol2.json`
- [ ] W-082 Research and input `seed-data/en-sets/rezero-memory-snow.json`
- [ ] W-083 Research and input `seed-data/en-sets/rezero-frozen-bond.json`
- [ ] W-084 Create `agents/sets/rezero-vol3.json` — set config file (MAL IDs, EN set list, JP set references)
- [ ] W-085 Identify Yuyutei set IDs for all 5 JP RE:Zero sets (Vol.1-3, Memory Snow, Frozen Bond) and populate jp_equivalent_sets in the config

## 6. Analysis Agent — Core

- [ ] W-100 Scaffold `agents/preorder/run.py`: CLI entry point, loads set config, orchestrates sub-agents
- [ ] W-101 Implement `agents/preorder/ip_strength.py`: call mcp-jikan tools, compute IP score, handle unranked fallback
- [ ] W-102 Implement `agents/preorder/en_historical.py`: load seed data, call mcp-ws-prices for current prices, compute % change and elapsed time
- [ ] W-103 Implement `agents/preorder/jp_set_analysis.py`: call mcp-yuyutei, process full JP card list, compute EV excluding AGR
- [ ] W-104 Implement `agents/preorder/synthesis.py`: apply V1 recommendation heuristics (see ARCHITECTURE.md), produce structured recommendation dict
- [ ] W-105 Implement `agents/preorder/post_generator.py`: take structured data dict, render Hugo-compatible markdown with front matter and section template
- [ ] W-106 Write `agents/preorder/README.md`: full docs for running the agent, extending it, interpreting output
- [ ] W-107 Test end-to-end dry run: does it produce a valid Hugo markdown file?

## 7. First Analysis — RE:Zero Vol.3

- [ ] W-120 Run preorder analysis agent: `python agents/preorder/run.py rezero-vol3`
- [ ] W-121 Review generated post in `blog/content/sets/rezero-vol3/preorder.md`
- [ ] W-122 Manual edit pass: verify all data points are accurate, add any commentary the agent missed
- [ ] W-123 Commit + push post; verify Hugo builds and renders correctly on GitHub Pages
- [ ] W-124 Post-run retrospective: what data was missing? what needed manual correction? → file issues for agent improvements

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
