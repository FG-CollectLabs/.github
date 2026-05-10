# Weiss Schwarz Analysis — Agent Coordination

This directory governs how agents (and the human) work the `ws-set-analysis` project without stepping on each other.

## Where things live

- `../ARCHITECTURE.md` — read this first. System design, data sources, agent flow, blog structure.
- `../TODO.md` — the task list. Check out work here.
- `../DECISIONS.md` — open decisions. Surface before guessing.
- `../` → actual implementation lives in `FG-CollectLabs/ws-set-analysis` repo (sibling, not this `.github` repo).

## Agent onboarding (read each session)

1. Read `../ARCHITECTURE.md` end-to-end. Source of truth for system shape, data sources, and terminology.
2. Skim `../DECISIONS.md` for open (`OPEN`) decisions affecting your task.
3. Open `../TODO.md`, find an unclaimed `[ ]` task.
4. Follow the checkout protocol below.

## Checkout protocol

### Claiming a task

1. Pick a task line starting with `[ ]`.
2. Edit it to:
   ```
   - [~claimed: <agent-id> <YYYY-MM-DD>] W-XXX <task description>
   ```
3. Commit only that change:
   ```
   git add projects/weiss-schwarz-analysis/TODO.md
   git commit -m "claim W-XXX: <short description>"
   git push
   ```
4. If push rejects, pull --rebase, pick a different task.

### Completing a task

1. Edit the line to:
   ```
   - [x] W-XXX <task description>  (PR: <url> | commit: <sha>)
   ```
2. Commit and push.

### Blocking / abandoning

- **Blocked:** `[!]` + append `— blocked by: <reason>`
- **Abandoning:** revert to `[ ]`; note why in commit message
- **Cancelled:** `[-]` + note why

## Rules

1. **Never renumber W-IDs.** They're stable references.
2. **Re-read ARCHITECTURE.md if it's been updated** since your last session.
3. **Surface open WD-XXX decisions** before guessing. File a DECISIONS.md entry if your task forces a choice.
4. **Data accuracy > completeness.** If a data point can't be verified, mark it as `estimated` or `unverified` in the output rather than guessing.
5. **Don't invent recommendation scores.** The heuristics are in ARCHITECTURE.md. If a set doesn't fit the heuristics cleanly, output all the data and flag for human review.

## Preorder agent quick reference

The preorder analysis agent lives in `ws-set-analysis/agents/preorder/`.

```bash
# From ws-set-analysis/ repo root
python agents/preorder/run.py rezero-vol3
```

This:
1. Loads `agents/sets/rezero-vol3.json`
2. Runs IP strength, EN historical, JP set analysis, synthesis
3. Writes `blog/content/sets/rezero-vol3/preorder.md`

**To add a new set for analysis:**
1. Create `agents/sets/<set-slug>.json` with the set config
2. Create seed data files in `seed-data/en-sets/` for any prior EN sets of that IP
3. Run the agent

## When in doubt

Ask Phil-Win (Phil-Win / nguye208@gmail.com) before:
- Resolving an `OPEN` decision in DECISIONS.md
- Inputting pull rate or preorder price data you're not certain about
- Publishing a post (pushing to main and deploying)
- Adding a new data source or MCP server not in ARCHITECTURE.md
