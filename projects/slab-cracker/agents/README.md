# Slab Cracker — Agent Coordination

This directory exists so multiple agents (or the human) can hand off and pick up slab-cracker work without losing context.

## Where things live

- `../ARCHITECTURE.md` — read this first. Current state, planned backend, full data flow, schema, glossary.
- `../TODO.md` — the task list. Check out work here.
- `../DECISIONS.md` — open decisions. Surface before guessing.

## Session handoff context (2026-05-19)

**What was explored this session:**
- Full architecture survey of both existing repos (frontend + extension)
- Confirmed: no backend exists, all data in localStorage (12 session cap), extension handles CORS scraping only
- User pain points identified:
  1. Same cert gets re-analyzed repeatedly (no dedup)
  2. No way to look at centering trends across many certs of the same card
  3. No crack decision support (e.g., "this PSA 9 has 10-worthy centering")

**Decision made by user:**
- Build a Go backend + Postgres following the `fg-collect-core` pattern
- Extension continues to scrape PSA/CGC; backend is persistence + query layer only (D-002 Option A)
- Store all analyses per cert, not just the latest (D-003 Option B)

**Decisions still OPEN** (need Phil sign-off before proceeding):
- D-001: Go/pgx/sqlc confirmed? (strong leaning yes)
- D-002: Extension scrapes, POSTs to backend (leaning Option A)
- D-003: Keep all analyses per cert (leaning Option B)
- D-004: Card catalog normalization — start simple with raw card_name

**Recommended next task**: Resolve open decisions with Phil, then start T-001 (scaffold `slab-cracker-backend` repo).

## Agent onboarding (read every time)

1. Read `../ARCHITECTURE.md` end-to-end — current state + planned schema.
2. Check `../DECISIONS.md` for any `OPEN` decisions affecting your task.
3. Open `../TODO.md`, find an unclaimed `[ ]` task, follow the checkout protocol below.

## Checkout protocol

### Claiming a task
1. Pick a `[ ]` task.
2. Edit it to: `[~claimed: <agent-id> <YYYY-MM-DD>] T-XXX <description>`
3. Commit only that change: `git add TODO.md && git commit -m "claim T-XXX: <description>"`

### Completing a task
1. Edit to: `[x] T-XXX <description>  (PR: <url> | commit: <sha>)`
2. Commit: `git commit -m "complete T-XXX: <description>"`

### Blocked / abandoned
- Blocked: change `[~]` → `[!]`, append `— blocked by: <reason>`
- Abandon: change `[~]` → `[ ]`, note why in commit message
- Cancelled: change to `[-]`, note why

## Rules

1. Never renumber task IDs.
2. One claim per agent at a time.
3. Re-read ARCHITECTURE.md if it was updated since your last session.
4. Surface OPEN decisions before guessing.
5. Don't add new task categories without Phil sign-off.

## When in doubt

Ask Phil (Phil-Win / himynameisfil@gmail.com) before:
- Resolving any OPEN decision in DECISIONS.md
- Creating a new repo
- Changing the Postgres schema in a way that breaks existing data
- Spending money (cloud resources, paid APIs)
