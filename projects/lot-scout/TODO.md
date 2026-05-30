# Lot Scout — TODO

## Phase 1: eBay pipeline (V1)
- [ ] Create `FG-CollectLabs/lot-scout` repo
- [ ] Register eBay developer app → get Finding API App ID (free at developer.ebay.com)
- [ ] Go service scaffold: config, PG connection, `seen_listings` table
- [ ] eBay scraper: `findItemsAdvanced` for configurable search terms + categories
- [ ] Photo downloader: fetch listing images → base64 for Claude
- [ ] Claude Haiku analysis worker: same prompt as bulk-lot-analyzer
- [ ] Deduplication: skip listings already in `seen_listings`
- [ ] Discord webhook notifier with embed format
- [ ] Notification filter: min bid floor, max red flags, value ratio
- [ ] Cron scheduler (robfig/cron or GitHub Actions)
- [ ] Deploy to Proxmox LXC

## Phase 2: Facebook Marketplace (Apify)
- [ ] Apify account + API token
- [ ] FB Marketplace scraper integration (apify/facebook-marketplace-scraper)
- [ ] Normalize FB listing schema to match eBay (title, price, photos, url)
- [ ] Tune run schedule to stay within Apify free tier

## Phase 3: Config / polish
- [ ] Per-search-term category hints (auto-tag pokemon vs mtg vs sports)
- [ ] Admin command in Discord to adjust thresholds on the fly
- [ ] History page / dashboard (reuse bulk-lot-analyzer History pattern)
