# Lot Scout — Architecture

Automated bulk lot monitor: scrapes eBay + Facebook Marketplace for card lot listings, runs each through Claude for bid analysis, fires Discord notifications for worthwhile deals.

## Repos

| Repo | Purpose |
|---|---|
| `FG-CollectLabs/lot-scout` | Go backend service + cron runner |

## Pipeline

```
Schedule (cron)
  → Scrapers (eBay API + Apify FB Marketplace)
  → Deduplication (PG seen_listings table)
  → Claude Haiku analysis (same prompt as bulk-lot-analyzer)
  → Filter (max_bid_usd >= floor && red_flags <= threshold)
  → Discord webhook notification
```

## Scrapers

### eBay (free)
- **API**: eBay Finding API — `findItemsAdvanced`
- **Search terms**: configurable per game category (pokemon bulk, magic cards lot, sports cards bulk, etc.)
- **Returns**: title, asking price, photos (up to 12), end time, auction vs BIN, seller rating
- **Rate limit**: 5,000 calls/day free
- **Auth**: App ID (client credentials, no OAuth needed for Finding API)

### Facebook Marketplace (Apify)
- **Actor**: `apify/facebook-marketplace-scraper`
- **Auth**: Apify API token
- **Cost**: ~$0.06–$0.25/run on residential proxies; infrequent checks stay within $5/month free tier
- **Returns**: title, price, photos, location, listing URL
- **Schedule**: 2–4x/day max per search term to control cost

## Storage

Reuse existing Proxmox PG instance (`.183`). New DB: `lot_scout`

```sql
seen_listings    -- deduplication; source + external_id + first_seen_at
analysis_results -- full Claude JSON output per listing
notifications    -- which listings were notified + when
```

## Analysis

Same Claude Haiku prompt as `bulk-lot-analyzer`. Inputs: photos (base64) + title + asking price + marketplace. Output: structured JSON with `max_bid_usd`, `opening_bid_usd`, `red_flags`, `notable_cards`.

## Notification filter

Configurable thresholds (env vars or DB config):
- `min_max_bid_usd` — skip if Claude values it under this (default: $10)
- `max_red_flags` — skip if too many red flags (default: 2)
- `min_value_ratio` — skip if asking price > X% of Claude's median value (default: 80%)

## Discord notification format

Embed per listing:
- Title + marketplace + asking price
- Claude's `opening_bid_usd` / `max_bid_usd`
- Notable cards (if any)
- Red flags (if any)
- Link to listing

## Deployment

Go service on Proxmox LXC (same pattern as other services). Cron via Go `robfig/cron`. Or GitHub Actions cron as a zero-infra alternative for V1.
