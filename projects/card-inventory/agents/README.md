# Card Inventory — Agent Coordination

This directory exists so multiple agents (or the human) can work the `card-inventory` project in parallel without stepping on each other.

## Where things live

- `../ARCHITECTURE.md` — read this first. The grand plan. Always read before starting any task.
- `../TODO.md` — the task list. This is where you check out work.
- `../DECISIONS.md` — open decisions. If your task touches one, surface it before guessing.

## Agent onboarding (read this every time)

1. Read `../ARCHITECTURE.md` end-to-end. It is the source of truth for system shape, repo split, storage layout, and terminology.
2. Skim `../DECISIONS.md` for any `OPEN` decisions that affect your task.
3. Open `../TODO.md` and find a task with status `[ ]` (open).
4. Follow the **checkout protocol** below.

## Checkout protocol

The TODO is a markdown file under git. Coordination is by atomic single-file commits.

### Claiming a task

1. Pick a task line that starts with `[ ]`.
2. Edit it in place to:
   ```
   - [~claimed: <agent-id> <YYYY-MM-DD>] T-XXX <task description>
   ```
   Where `<agent-id>` is your handle (e.g., `agent-fil`, `claude-2026-05-05-A`, `human-fil`).
3. Commit **only** that change to `TODO.md`:
   ```
   git add TODO.md
   git commit -m "claim T-XXX: <short description>"
   git push
   ```
4. If the push rejects (someone else claimed first), `git pull --rebase`, pick a different task, retry.

### Working the task

- Do the work in the appropriate repo (likely a sibling repo like `card-inventory-backend`, not this `.github` repo).
- Reference the task ID (`T-XXX`) in your commit messages and PR titles for traceability.
- If you need to break the task into subtasks, add them as new IDs (next free number) and complete the parent only when all subtasks are done.
- If you discover the task was misspecified, update its description in `TODO.md` and note the change in the commit message.

### Completing a task

1. Edit the line to:
   ```
   - [x] T-XXX <task description>  (PR: <url> | commit: <sha>)
   ```
2. Commit:
   ```
   git add TODO.md
   git commit -m "complete T-XXX: <short description>"
   git push
   ```

### Blocking / abandoning a task

- **Blocked:** change `[~]` → `[!]` and append `— blocked by: <reason or other task ID>`.
- **Abandoning:** change `[~]` → `[ ]` (release the claim). Note in commit message why.
- **Cancelled (no longer needed):** change to `[-]` and note why.

## Rules

1. **Never renumber task IDs.** They're stable references in commits, PRs, and other docs.
2. **One claim per agent at a time** unless tasks are trivially independent (e.g., editing two different repos).
3. **Re-read ARCHITECTURE.md if it's been updated** since your last session — assumptions drift.
4. **Surface OPEN decisions** in DECISIONS.md before making a guess that locks one in. If your task forces a decision, propose it in DECISIONS.md first, then proceed.
5. **Don't invent terminology.** Use the glossary in ARCHITECTURE.md. If a needed term is missing, add it.
6. **Don't add new task categories** without human sign-off. New tasks within existing categories are fine.

## When in doubt

Ask the human (Phil-Win / himynameisfil@gmail.com) before:
- Resolving an OPEN decision in DECISIONS.md
- Starting any task in section 7 (Marketplace Integrations) — these are explicitly v2
- Adding a new repo
- Making a schema change that breaks an already-shipped table
- Spending money (cloud resources, paid APIs, domain purchases)
