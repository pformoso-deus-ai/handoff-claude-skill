# handoff

A Claude Code skill that captures the state of a long session into a structured handoff document, so a fresh session — or another machine, or another day — can resume cleanly instead of re-deliberating from scratch.

The skill has two modes:

- **Write** — wrap up the current session and save a `HANDOFF.md` next to your code.
- **Resume** — load an existing handoff, verify the world hasn't drifted since it was written, then pick up at the next concrete step.

Both modes are intentionally one skill so the triggering language ("wrap this up", "pick up where we left off") routes to the same entry point.

## What ships

Only one file ships when this is packaged: [handoff/SKILL.md](handoff/SKILL.md). Everything else in this repo is for authoring and iterating — tests, fixtures, and notes.

## Install

### Option A — copy into your skills directory

```bash
mkdir -p ~/.claude/skills/handoff
cp handoff/SKILL.md ~/.claude/skills/handoff/
```

Restart Claude Code (or open a new session) — the skill will be picked up automatically and triggered by the phrases listed in its frontmatter.

### Option B — install via `.skill` package

Use the `anthropic-skills:skill-creator` skill's packaging script against the `handoff/` directory. The output is a single `.skill` file you can hand to a teammate.

## Use

### Write a handoff

In any Claude Code session, say one of:

- `/handoff`
- "wrap this up so I can keep going tomorrow"
- "stop here for today"
- "context is filling up, save what we have"

The skill produces `HANDOFF.md` in the working directory. It will not run `git add` / `git commit` — handoff docs are intentionally separate from your commit history.

### Resume from a handoff

In a fresh session in the same directory:

- `/handoff`
- "pick up where we left off"
- "resume from handoff"
- "what was I working on"

The first thing the skill does is run the verification commands embedded in the doc (`git status`, a test command, a grep — whatever the writer specified). If those diverge from what the doc expected, it stops and surfaces the discrepancy rather than acting on stale assumptions.

If a `HANDOFF.md` is present when you start a new session and you're not sure where to begin, the skill also triggers from a generic question — no exact phrase needed.

## Develop

This repo is the authoring workspace, not a deployed program. The iteration loop is driven by the [`anthropic-skills:skill-creator`](https://github.com/anthropics/skills) skill:

1. Edit [handoff/SKILL.md](handoff/SKILL.md).
2. Update or add test prompts in [evals/evals.json](evals/evals.json).
3. Re-invoke `skill-creator` — it spawns parallel runs (with-skill vs. baseline), grades them against the assertions inlined in each eval's `expected_output`, and aggregates a benchmark.
4. Review failing cases, revise the skill, repeat.

See [CLAUDE.md](CLAUDE.md) for the longer version of the workflow and design notes.

## Layout

```
handoff/
  SKILL.md              # the skill itself — only file that ships
evals/
  evals.json            # eval prompts, with assertions inline
  fixtures/
    session-1.md        # simulated prior session (input to a "write" eval)
    HANDOFF.md          # well-formed handoff doc (input to a "resume" eval)
CLAUDE.md               # repo orientation for Claude Code
README.md
```

`handoff-workspace/` is created on demand by the iteration loop and holds per-iteration eval output. It's not part of the shipped skill.

## Design notes

A few things about the skill that aren't obvious from reading SKILL.md cold:

- **The handoff document format is load-bearing.** The resume path parses headers from the doc the write path produces. Changing the template means changing both modes together — the template lives in SKILL.md under the "Required sections" block.
- **Verification commands are the linchpin.** A handoff is a snapshot; the world moves. The writer must include verification commands and the reader must run them before any edit. Removing that step would silently break cross-day or cross-machine resumes.
- **Staleness threshold is currently ~7 days** — an experimental starting value, intended to be tuned from real usage rather than picked as a round number.

## Status

Pre-1.0, iterating. The current scope is paused-work handoff; a separate "summarize-only" mode and persistent archives (`~/.claude/handoffs/`) are out of scope for now.
