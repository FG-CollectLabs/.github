# Weiss Schwarz Analysis — Architectural Decisions

> Lightweight ADR log. Each decision: context, options considered, choice, rationale.
> Prefix all IDs with `WD-` to distinguish from other project ADRs.

---

## WD-001 — Single repo for blog + agents + MCP servers (V1)

**Date:** 2026-05-10
**Status:** Accepted

**Context:** Could split blog (Hugo), agents (Python), and MCP servers (Python) into 3 separate repos.

**Options:**
1. Single repo: `ws-set-analysis/` with `blog/`, `agents/`, `mcp/` directories
2. Two repos: `ws-set-analysis` (blog) + `ws-analysis-tools` (agents + MCP)
3. Three repos: blog, agents, MCP servers each separate

**Decision:** Option 1 — single repo for V1.

**Rationale:** Only one developer. Colocation removes cross-repo coordination overhead. Split if MCP servers become useful for other projects (e.g., market-tracker could consume mcp-yuyutei) or if the blog gets a different deployment pipeline.

---

## WD-002 — Python for MCP servers and agent orchestration

**Date:** 2026-05-10
**Status:** Accepted

**Context:** MCP SDK exists for Python and TypeScript. Agent orchestration could be Python or Go.

**Options:**
1. Python (BeautifulSoup + httpx + anthropic SDK)
2. TypeScript (Playwright + fetch + anthropic SDK)
3. Go (chromedp for scraping + anthropic SDK)

**Decision:** Option 1 — Python.

**Rationale:** BeautifulSoup + requests/httpx is the standard scraping stack. Playwright is available if JS-rendered sites require it. The anthropic Python SDK is mature. The user's Go expertise is better reserved for backend services, not scraper tooling.

---

## WD-003 — Hugo for the blog, GitHub Pages for hosting

**Date:** 2026-05-10
**Status:** Accepted

**Context:** Blog needs to be viewable in a browser. Options: static site generator, markdown files in GitHub, or a full frontend.

**Options:**
1. Hugo static site → GitHub Pages
2. Plain markdown in GitHub (renders on GitHub.com)
3. Vite/TS React app (matches existing frontend pattern)

**Decision:** Option 1 — Hugo.

**Rationale:** User is familiar with Hugo. GitHub Pages deploys automatically from the repo. Markdown content is trivially version-controlled. A Vite app would be overkill for what is essentially a rendered document.

**Open question (WD-003a):** Pick a Hugo theme — or build a minimal custom theme. Lean toward a clean readable theme (PaperMod or similar) and customize minimally.

---

## WD-004 — Jikan (unofficial MAL API) over direct MAL scraping

**Date:** 2026-05-10
**Status:** Accepted

**Context:** Need anime/manga rank, score, members from MyAnimeList.

**Options:**
1. Jikan v4 REST API (unofficial, no auth, public)
2. Direct MAL scraping (HTML)
3. MAL official API (requires OAuth, has limited free tier)

**Decision:** Option 1 — Jikan.

**Rationale:** Jikan provides exactly the data needed (rank, score, members, favorites, popularity) in clean JSON. No auth. Official MAL API OAuth flow is unnecessary overhead for read-only analytics. Direct scraping is fragile against MAL's HTML changes.

---

## WD-005 — Manual seed data for EN pull rates and preorder prices (V1)

**Date:** 2026-05-10
**Status:** Accepted

**Context:** Historical EN preorder prices and pull rates need to come from somewhere. Bushiroad publishes pull rate PDFs. Historical preorder prices are on vendor sites or the WS community.

**Options:**
1. Scrape Bushiroad EN product pages for pull rate PDFs and parse them
2. Scrape heartofthecards.com / community wikis for pull rates
3. Manually research and input as JSON seed files

**Decision:** Option 3 — manual seed data for V1.

**Rationale:** PDF parsing is brittle and high-effort. Community sources are not consistently formatted. For V1 we're analyzing a handful of sets (4 EN + 5 JP). Manual input is 30 minutes of work and gives ground-truth data. Automate later when the pattern is stable and we're covering many sets.

---

## WD-006 — Exclude AGR and signed rarities from JP EV calculation

**Date:** 2026-05-10
**Status:** Accepted

**Context:** Japanese WS sets include autograph (AGR) cards signed by voice actors. These command extremely high prices (sometimes ¥5000-50000+) but never appear in English prints.

**Decision:** Exclude AGR and any other "signed" rarity from JP box EV computation. Include them in the data display as a separate section ("JP-only exclusions") for transparency.

**Rationale:** EN preorder analysis must be apples-to-apples with what EN buyers will actually receive. Inflating EV with unattainable pulls would lead to bad recommendations.

---

## WD-007 — Stage-tagged posts: same set, multiple snapshots over time

**Date:** 2026-05-10
**Status:** Accepted

**Context:** The core investment question is whether to preorder vs wait. To improve recommendations over time, we need to track our accuracy: did the price dip? By how much? For how long?

**Decision:** Each set gets separate Hugo posts per stage: `preorder`, `30d`, `90d`, `1yr`. Posts share the same set slug as a directory (`content/sets/<slug>/`), with a file per stage (`preorder.md`, `30d.md`, etc.).

**Rationale:** Lets us compare prediction vs reality. Gives readers returning after release a current snapshot. Enables a "how did we do?" accuracy tracker over time.

---

## WD-008 — OPEN: Google Trends integration for unranked IPs

**Date:** 2026-05-10
**Status:** Open

**Context:** Some IPs (especially manga-only or obscure) won't have a high MAL anime rank. Google Trends (`pytrends`) can give relative search volume.

**Options:**
1. pytrends Python library (unofficial Google Trends API)
2. Manual Google Trends screenshot + note
3. Skip if no MAL rank — just flag as "unranked"

**Decision:** TBD. For RE:Zero Vol 3 (first analysis), MAL data is sufficient. Defer this decision until we hit an IP without good MAL data.

---

## WD-009 — OPEN: TCGPlayer scraping vs API for EN prices

**Date:** 2026-05-10
**Status:** Open

**Context:** TCGPlayer has public price endpoints but also blocks scrapers. The market price for EN WS cards and sealed boxes is the key data point.

**Options:**
1. TCGPlayer API (requires TCGPlayer Pro account and API key)
2. Public TCGPlayer price endpoint scraping (fragile)
3. Use 130point.com or similar TCG price aggregator

**Decision:** TBD. Start with whatever is simplest for the first analysis. If scraping breaks, evaluate 130point.com or manual data entry.

---

## WD-010 — Competitive standing data source: weissteatime.com

**Date:** 2026-05-10 (resolved 2026-05-17)
**Status:** Accepted

**Context:** Whether an IP is competitively relevant affects sustained demand. WS is a non-rotating format where powercreep is the primary competitive driver — new sets for a top-tier IP (e.g., OSK) strictly upgrade existing decks, sustaining demand. Mid-tier sets may have "missing piece" potential where a future release unlocks their viability.

**Options:**
1. Scrape Bushiroad EN tournament top-8 deck lists from ws-tcg.com/events
2. Manual tag in seed config (competitive: true/false/moderate)
3. weissteatime.com tournament masterposts — community-curated, covers EN Worlds, BCS, BSF seasons with field % and top-cut conversion rates
4. Defer — note it as "not analyzed" until tooling exists

**Decision:** Option 3 — `mcp-weissteatime` MCP server scraping weissteatime.com tournament deck category.

**Rationale:** weissteatime.com is the de-facto authoritative community source for EN WS competitive results. It covers Worlds, BCS (regional circuit), and BSF (store finals) with consistent structure, set codes, field %, and top-cut data. Bushiroad's official site lacks aggregated meta statistics. Manual tags don't capture the "mid-competitive but rising" nuance needed for the powercreep and missing-piece investment theses.

**Competitive tier definitions (derived from multi-season data):**
- `high`: ≥15% field share in any major event, OR multiple seasons ≥10%, OR finalist placements at Worlds
- `mid-high`: 8–15% field OR strong conversion rate (≥18%) at ≥5% field across 2+ events
- `mid`: 3–8% field with meaningful top-cut appearances; potential "missing piece" — a future release could unlock viability
- `low`: <3% field or isolated results only
- `none`: no tournament presence found

**Synthesis modifier:** `high` → +1 tier upgrade (powercreep demand driver); `mid-high` → neutral; `mid` → neutral + flag "missing piece" in post; `low`/`none` → −1 tier downgrade.
