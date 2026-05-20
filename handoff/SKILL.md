---
name: handoff
description: Compress the current Claude Code session into a handoff document so the user can resume cleanly in a fresh session, OR resume work from an existing handoff doc. Use this skill whenever the user types `/handoff`, asks to terminate, wrap up, pause, save progress, "stop here for today", flags that context is filling up, says "pick up where we left off", "continue from yesterday", "resume from handoff", "what was I working on". Also trigger when the user opens a new session in a directory containing a HANDOFF.md and isn't sure where to start.
---

# Handoff

This skill has two modes. Pick based on what the user is doing:

- **Write a handoff** — when the user wants to end the current session and save state for later.
- **Resume from a handoff** — when the user is starting fresh and there's existing handoff state to load.

If both apply (e.g. "wrap this up so I can keep going tomorrow" right after resuming), do the resume first and treat writing as a separate action when the user signals it.

## Why this skill exists

Long sessions accumulate decisions, dead ends, mental models, and half-finished edits. None of that survives the next session unless it's captured deliberately. A naive end-of-session summary loses the *reasoning* behind decisions and the *specificity* of where work was paused — and a fresh instance ends up either re-deliberating or guessing.

A good handoff doc captures the **state of the work** plus the **state of the previous instance's understanding**, so the next instance can act, not just read.

The doc is not a transcript. It is a working brief.

---

## The Handoff Contract

The handoff document is an interface between two Claude instances across time. The writer (Mode 1) commits to producing it in this shape; the reader (Mode 2) commits to honoring it in this way. Both sides depend on the contract — don't drift from it without updating both modes.

### Artifact

- **Path:** `HANDOFF.md` at the working directory root. One canonical file. Honor a custom path only if the user names one explicitly. Never write outside the working directory.
- **Format:** Markdown with the section headers below, in this order. Headers are load-bearing — the reader uses them to navigate.
- **Length:** target ≤ 150 lines. If it grows past that, you're dumping transcript; cut.

### Required sections, in order

```markdown
# Session Handoff
Created: <YYYY-MM-DD HH:MM TZ>
Working dir: <absolute path>
Status: <in-progress | blocked | ready-to-resume>
Base commit: <`git rev-parse HEAD`, or "none — not a git repo">
Working tree: <"clean" | "dirty (N files — see Verification)">
Branch: <`git branch --show-current`, or "detached HEAD", or "none — not a git repo">

## Goal
<one paragraph. What we are actually trying to accomplish, framed as it stands now (not the original ask if it's drifted).>

## Where I left off
<one short paragraph. Narrative of the last 2–3 turns — what was being done when the session paused.>

## Decisions made (with rationale)
- <decision> — <why. Include the constraint or trade-off that drove it.>

## Done
- <thing> — [file.ts:42](relative/path/file.ts:42)

## In progress
- <thing> — paused at [file.ts:88](relative/path/file.ts:88). Next concrete step: <do X to Y, looking at Z>.

## Dead ends (do not retry)
- <approach tried> — <why it didn't work. One line.>

## Verification before resuming
Run these to confirm state hasn't drifted since this doc was written. The first three are **mandatory when the work is git-tracked** — they catch the cross-day or cross-machine case where the doc's `file:line` refs would otherwise point at the wrong code.

\`\`\`bash
git rev-parse HEAD         # Expected: <Base commit from header>
git status --porcelain     # Expected: <verbatim porcelain output captured at write-time, or empty if clean>
git branch --show-current  # Expected: <Branch from header>
<additional command(s) — tests, greps, runtime checks>
\`\`\`

Expected: <one line on what "good" looks like, beyond the git checks.>

## Next steps
1. <concrete first action, with file:line where applicable>

## Open questions for the user
- <question, if any>
```

**Section presence rules:**
- All sections must be present as headers.
- `Dead ends` and `Open questions` may be left empty (a single line `_none_` is fine). Other sections must have content.
- `Done` and `In progress` may have only one of them populated if the work hasn't reached the other state yet.
- `Base commit`, `Working tree`, and `Branch` header fields are mandatory when the working dir is a git repo. Substitute the literal `"none — not a git repo"` placeholders when it isn't.

### Writer obligations (Mode 1)

- Produce every required section in the order above.
- Use file:line links (`[label](path:line)`) in `Done` and `In progress` entries wherever a specific location matters. Vague entries like "fixed the auth bug" are insufficient — name the file.
- The `Next steps` list must lead with a *concrete* first action (file to open, function to read, change to make), not an objective ("continue the feature").
- `Verification before resuming` commands must be safe to run blind: read-only or idempotent. No deploys, no destructive git, no irreversible writes.
- Capture `Base commit` (from `git rev-parse HEAD`), `Working tree` state, and `Branch` in the header. The first three verification commands MUST be the git-state checks (`git rev-parse HEAD`, `git status --porcelain`, `git branch --show-current`), with expected values matching the header. If the working dir is not a git repo, write the `"none — not a git repo"` placeholders and skip the three git checks.
- Total length ≤ ~150 lines.
- **Don't auto-commit.** Do not run `git add`, `git commit`, or any state-mutating git command without explicit user opt-in. If the user signals cross-machine resume intent (e.g., "I'll continue on my other laptop") and the working tree is dirty, prompt before writing — see the cross-machine edge case below. The default remains: no commits as a side effect of writing the handoff.
- If a `HANDOFF.md` already exists, rename it to `HANDOFF.<original-Created-date>.md` before writing the new one — unless the user explicitly says to overwrite. Preserving history is cheap.

### Reader obligations (Mode 2)

- Read `HANDOFF.md` (or the path the user named) before doing anything else.
- Execute the `Verification before resuming` commands **first**, before any edits or planning. If a command fails or its output diverges from the doc's expectation, **stop and surface the discrepancy** — do not silently adapt. The doc reflects a past moment; the world may have moved.
- Specifically for the three git-state checks:
  - If `git rev-parse HEAD` doesn't match `Base commit` → stop. The `file:line` refs in `Done` / `In progress` were captured against a different commit and may not resolve to the right code. Surface the divergence; offer to check out the `Base commit` or rewrite the next steps against the current commit.
  - If `git status --porcelain` doesn't match what the doc declared → stop. Uncommitted work captured at write-time is either not on this machine, or has been modified since. Surface and ask the user to reconcile (pull the patch, apply a stash, or revise the doc).
  - Branch mismatch alone is less critical — flag it, ask the user if it's intentional (e.g., they're on a worktree), and continue if confirmed.
- Acknowledge in ≤3 lines: the goal, where things stand, and the next concrete action you intend to take. Then wait for the user to confirm — unless they already said "just continue" or equivalent.
- Treat the doc as a snapshot, not as truth. If the code at a cited `file:line` doesn't match what the doc says is there, the *code* is the source of truth. Flag the divergence to the user.
- `Open questions for the user` are time-stamped. If the question may have been answered offline since the doc was written, ask the user before acting on it.

### Failure modes and how to handle them

- **Missing required section** → treat the handoff as malformed. Show the user what's missing and ask whether to proceed anyway or rewrite.
- **Multiple in-progress threads in one doc** → each thread should have its own entry. Pick one to resume (or ask the user which) — don't try to juggle both.
- **Verification commands fail** → stop. Report what diverged. Do not improvise a fix that touches the next-steps work, because the diverged state may invalidate it. Subcase: if the failure is on `git rev-parse HEAD` or `git status --porcelain` specifically, the cited `file:line` references in `Done` / `In progress` are aimed at a different state of the code than what's checked out. Resuming requires either checking out the `Base commit`, or rewriting the next steps against current code with the user's confirmation — don't pick one silently.
- **Doc is more than ~7 days old** → flag the staleness up front and recommend writing a fresh handoff from scratch with the user, rather than acting on stale assumptions.

---

## Mode 1: Write a handoff

### Step 1 — Reconstruct, don't dump

Before writing anything, build a mental model of the session by answering these in order. Don't skip ahead; each answer feeds the next.

1. **What is the *current* goal?** Not the original ask — the goal as it stands now. Goals drift during sessions, and the doc must reflect where things actually are.
2. **What decisions have been committed, and why?** A decision without rationale is brittle: the next instance won't know how to handle adjacent edge cases.
3. **What's the concrete state?** Files touched (with paths and line refs), what's done, what's in progress, what's queued but not started.
4. **What dead ends were explored?** Approaches that didn't work, with one line on *why*. This is high-value — it prevents the next instance from wasting fresh context retrying them.
5. **What is the *next concrete step*?** Not "continue the feature." Something like: "Open `src/auth/middleware.ts`, the validation block around line 88 currently throws on null tokens — replace with the early-return pattern used in `legacyAuth.ts:42`."
6. **What command can verify the state hasn't drifted?** `git status`, `npm test`, a `grep` for a symbol that should exist. The reader runs this first.

If the user is present, ask at most one or two clarifying questions about #1 and #5 — those are the parts most likely to be wrong, and the user can answer in seconds. Don't interview them on the rest.

### Step 2 — Check for an existing handoff

Apply the writer obligation above: if `HANDOFF.md` already exists, read its `Created` timestamp, rename it to `HANDOFF.<that-date>.md`, then proceed. If the user explicitly says to overwrite, skip the rename.

### Step 3 — Write the doc

Use the template from the **Required sections** block above, exactly. Fill every section per the writer obligations.

### Step 4 — Confirm and stop

After writing, print a short summary in chat (≤ 4 lines):

- Path to the handoff doc.
- One line on what's captured (goal + next step).
- The exact resume phrase: *"/handoff"* or *"resume from handoff"*.

Stop there. Do not commit to git. Do not preemptively start the next task.

### What NOT to include

- Full code blocks of edits already applied — the files have them.
- Long quotes from the conversation — paraphrase.
- Your own chain of thought — only the conclusions.
- Anything trivially reachable from `git log`, `git diff`, or reading a cited file.

---

## Mode 2: Resume from a handoff

### Step 1 — Locate and read

Default: read `HANDOFF.md` from the working directory root. If the user names a different path, use that. If the file is missing, say so and ask the user where it is — do not guess or scan the filesystem.

### Step 1.5 — Environment readiness

Before running the doc's verification commands, confirm that environment dependencies which live *outside* git are present in this working tree. Git worktrees inherit checked-in config but not machine-local artifacts, so a fresh worktree can read `HANDOFF.md` correctly while still missing parts of the reasoning environment the resumer expects.

Run the checks below in order. Each check has the form: *detect → repair if safe → otherwise surface and ask*.

**CodeGraph index** (if `.codegraph/config.json` exists in the working dir):
- Detect: is `.codegraph/codegraph.db` present and non-empty?
- If missing:
  - Look for an existing `.db` in sibling worktrees of the same repo (`../*/.codegraph/codegraph.db`).
  - If found → copy the three files (`codegraph.db`, `codegraph.db-wal`, `codegraph.db-shm` — all three are needed for SQLite WAL consistency) into `.codegraph/`, then run `codegraph sync` to update against the current working tree's diff. This is fast (seconds) and safe; do it without prompting.
  - If no sibling `.db` exists → ask the user before running `codegraph init -i`. A cold index can take several minutes on a large repo, and the user may prefer to defer or skip CodeGraph for this session.
- After bootstrap, **explicitly tell the user**: the `.db` is ready, but the MCP server only inspects it at session start, so the `codegraph_*` tools will not be loaded until the session is restarted. Suggest finishing the resume (Steps 2–4) first and restarting after the acknowledgement — that way the user keeps the orientation in chat across the restart.

If `.codegraph/config.json` is absent, the project hasn't adopted CodeGraph; skip this check.

(Additional checks can be appended here as the team identifies more out-of-git environment dependencies — e.g., Docker services up, `.env` present, generated SDKs in place. Same shape: detect, repair if safe, surface otherwise.)

### Step 2 — Verify

Run the `Verification before resuming` commands per the reader obligations above. Pass → continue. Fail or divergent → stop and surface.

### Step 3 — Acknowledge

Three lines max: goal, state, next concrete action. Wait for confirmation unless told otherwise.

### Step 4 — Act

Follow `Next steps` in order. If a step turns out to be wrong because state has shifted, pause and ask — don't improvise around a doc that reflects yesterday's understanding.

---

## Edge cases for the user

**Terminate but the work is genuinely complete.** Suggest skipping the handoff doc — a short summary in chat is enough. Handoff docs are for paused work, not finished work.

**Terminate but nothing has happened yet.** Push back: "There's not much state to capture yet. Want me to write one anyway, or pick this up later?"

**Emergency handoff (context about to overflow).** Prioritize `In progress` and `Next steps`. Decisions and dead ends are nice-to-have under time pressure; specificity about *where the cursor is* matters most.

**Cross-machine resume with a dirty tree.** If the user says they'll resume on a different laptop and `git status --porcelain` is non-empty, the cited `file:line` references in the handoff won't resolve there — those edits live only on this machine. Before writing the doc, ask which option:
1. **Commit + push first** (recommended). The `Base commit` in the header then points at code that exists on the other laptop after a `git pull`.
2. **Generate a `handoff.patch` alongside** (`git diff > handoff.patch`, and `git diff --staged >> handoff.patch` if anything is staged). The reader on the other laptop applies it before resuming.
3. **Write the handoff anyway** and mark `Working tree: dirty (laptop-local)`. The next-steps narrative will be readable, but the cited lines will diverge until the user returns to this machine.

Don't pick silently — the trade-off (commit hygiene vs. patch sprawl vs. laptop-local scope) is the user's call.
