# Card Identifier — TODO

Goal: scan Commander deck cards, identify via pHash, export full eBay listings with hosted images.

---

## One-time deployment (fg-card-app LXC @ 192.168.86.198)

- [ ] SSH to 192.168.86.198 and verify Docker is installed (`docker --version`)
- [ ] Verify NAS bind-mount is active: `ls /mnt/scans` should not be empty (or at least be the right dir)
      If missing, add to LXC 108 config in Proxmox: `mp0: /mnt/pve/nas-nfs/fg-card-scans,mp=/mnt/scans`
- [ ] Create config dir: `mkdir -p /etc/card-identifier`
- [ ] Copy env template: `scp card-identifier-backend/deploy/env.production.example root@192.168.86.198:/etc/card-identifier/env`
      Then edit on the LXC: fill in real DB password (`pg-servers.json` → app.password) and a generated ADMIN_API_TOKEN
- [ ] Copy pricing rules: `scp card-identifier-backend/pricing.yaml root@192.168.86.198:/etc/card-identifier/pricing.yaml`
- [ ] Run DB migrations (from dev machine):
      `goose -dir card-identifier-backend/migrations postgres "postgres://fg_app:<pw>@192.168.86.181:5432/card_identifier?sslmode=disable" up`
- [ ] Run deploy: `cd card-identifier-backend && ./deploy.sh` (defaults to 192.168.86.198)
- [ ] Test health: `curl http://192.168.86.198:8080/healthz` → `ok`

## Nginx + HTTPS (for eBay image URLs)

- [ ] Install nginx on LXC: `apt install -y nginx certbot python3-certbot-nginx`
- [ ] Copy nginx config: `scp card-identifier-backend/deploy/nginx-cards.conf root@192.168.86.198:/etc/nginx/sites-available/cards`
- [ ] Enable site: `ln -s /etc/nginx/sites-available/cards /etc/nginx/sites-enabled/cards && nginx -t && nginx -s reload`
- [ ] DNS: point `cards.futuregadgetlabs.com` A record → public IP of home router (port-forward 80+443 → 192.168.86.198)
- [ ] TLS: `certbot --nginx -d cards.futuregadgetlabs.com` then `nginx -s reload`
- [ ] Test: `curl https://cards.futuregadgetlabs.com/healthz` → `ok`

## pHash seeding (per Commander set)

Run these via `curl` or the frontend Settings → "Ingest set by search URL" (if wired up):

- [ ] Get TCGPlayer search URL for each set (e.g. `https://www.tcgplayer.com/search/magic/...?q=...&view=grid`)
- [ ] POST to backend (replace TOKEN and URL):
      ```
      curl -X POST https://cards.futuregadgetlabs.com/phashes/ingest/set \
        -H "Authorization: Bearer TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"search_url":"<tcgplayer-search-url>"}'
      ```
- [ ] Commander: Secrets of Strixhaven — [ ] (add other decks being broken down)

## eBay setup (one-time)

- [ ] On eBay: Account → Business policies → create Payment, Shipping, Return policies
- [ ] In the frontend Settings drawer (⚙): fill in Payment/Shipping/Return policy names, postal code
- [ ] Set default card condition (e.g. "Near Mint or Better")

## Frontend (Settings → API URL)

- [ ] Set API URL to `https://cards.futuregadgetlabs.com` in the Settings drawer
- [ ] Set API Token to the ADMIN_API_TOKEN from the LXC env file

## Scanning workflow

1. Open the frontend (`npm run dev` or serve the built dist/)
2. Click "New scanning session" → pick the Commander set + enable "top loader" if applicable
3. Drag-and-drop scanned card images (front first; back if in front+back mode)
4. Review identified cards — Confirm high-confidence hits, pick from candidates for medium
5. Click "Get live prices (all)" to fetch TCG + ManaPool + eBay sold prices
6. Click "Export eBay CSV" → upload to eBay Seller Hub → File Exchange

---

## Future enhancements

- [ ] Bulk ingest via Scryfall JSON (faster than TCGPlayer CDN, covers tokens + extras)
- [ ] Frontend deployment to the LXC so scanning works from any device on the LAN
- [ ] Per-card foil checkbox (toggle to a foil version of the same product ID)
- [ ] Batch scan confirm: auto-confirm all high-confidence hits with one click
