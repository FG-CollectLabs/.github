# Graded Regrade Tracker — TODO

New repo: `FG-CollectLabs/graded-regrade-tracker`

---

## Phase 1 — Repo skeleton

- [ ] Create GitHub repo `FG-CollectLabs/graded-regrade-tracker`
- [ ] Initialize Go module `github.com/FG-CollectLabs/graded-regrade-tracker`
- [ ] Add standard project structure: `cmd/`, `internal/`, `migrations/`, `queries/`, `sqlc.yaml`
- [ ] Copy `.golangci.yml`, `Makefile` patterns from `fg-collect-core`
- [ ] Write `CLAUDE.md` with project overview and stack
- [ ] Set up GitHub Actions CI (lint + build on push)

---

## Phase 2 — Database setup

- [ ] Provision `graded_tracker` database on `192.168.86.182` (market-tracker Proxmox instance)
- [ ] Create DB user `fg_graded_app` with least-privilege grants
- [ ] Set up Goose migration runner in `cmd/migrate/main.go`
- [ ] Write `migrations/0001_init.sql` — tracked_cards, purchases, grading_company enum
- [ ] Write `migrations/0002_analysis.sql` — pre_grading_analyses
- [ ] Write `migrations/0003_submissions.sql` — grading_submissions, grading_results
- [ ] Write `migrations/0004_sales.sql` — sales
- [ ] Write `migrations/0005_views.sql` — venture_pnl view
- [ ] Run migrations locally and verify schema

---

## Phase 3 — sqlc queries

- [ ] Write `queries/tracked_cards.sql` — UpsertTrackedCard, GetTrackedCard, ListTrackedCards
- [ ] Write `queries/purchases.sql` — InsertPurchase, ListOpenPurchases, GetPurchase
- [ ] Write `queries/analyses.sql` — InsertAnalysis, GetLatestAnalysisForPurchase
- [ ] Write `queries/submissions.sql` — InsertSubmission, ListSubmissionsForPurchase
- [ ] Write `queries/results.sql` — InsertResult, ListResultsForSubmission, ListResultsWithGrade
- [ ] Write `queries/sales.sql` — InsertSale, ListSalesForResult
- [ ] Write `queries/reports.sql` — VenturePnL, GradeAccuracy
- [ ] Run `sqlc generate`, fix any type issues

---

## Phase 4 — CLI commands

- [ ] `cmd/add/main.go` — subcommand router (`purchase`, `analysis`, `submission`, `result`, `sale`)
  - [ ] `add purchase` — interactive prompts or flags; looks up/creates tracked_card
  - [ ] `add analysis` — prompts for 4 subscores + predicted grades + strategy
  - [ ] `add submission` — prompt for company, service level, fee, tracking
  - [ ] `add result` — prompt for grade, cert number, pop count
  - [ ] `add sale` — prompt for platform, price, fees
- [ ] `cmd/list/main.go`
  - [ ] `list purchases` — table of open positions with purchase price
  - [ ] `list results` — table of graded results, predicted vs actual
- [ ] `cmd/report/main.go`
  - [ ] `report pnl` — P&L per purchase; join market-tracker DB for contemporaneous prices
  - [ ] `report accuracy` — predicted vs actual grade accuracy, by company
  - [ ] `report signals` — open positions that now have a market signal (query MT watchlist)

---

## Phase 5 — Market context join

- [ ] Add `internal/marketdb/client.go` — read-only pgx connection to `market-tracker` DB
- [ ] Implement `GetGradedContextForCard(cardID uuid, purchaseDate date)` — returns PSA 9, PSA 10, CGC 10 prices + gem rates for the week of purchase
- [ ] Wire into `report pnl` output: show "market at purchase" block alongside P&L
- [ ] Handle case where `market_tracker_card_id` is not set (show warning, skip context)

---

## Phase 6 — Config & deployment

- [ ] `internal/config/config.go` — load DB DSN from env vars (`GRADED_DB_DSN`, `MT_DB_DSN`)
- [ ] Write `.env.example`
- [ ] Write `deploy/README.md` — how to run CLI on dev machine (no server needed in v1)
- [ ] Add credentials to `C:\Users\nguye\.config\fg-collectlabs\pg-servers.json`

---

## Parking lot

- REST API + Hugo dashboard (v2)
- Photo storage: upload front/back images of raw card before submission
- Lot tracking: group multiple purchases under a "lot" bought from one seller
- Bulk submission tracking (e.g., 10-card PSA economy batch as one submission)
- Export to CSV for tax purposes
- Compare predicted accuracy across card types (foil vs non-foil, old set vs new set)
- Integrate with graded-market-watch watchlist — flag when an open position hits a signal
