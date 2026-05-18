# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A development workspace for a single Claude Code **skill**: [handoff](handoff/SKILL.md). The skill compresses a long Claude Code session into a structured handoff document so the user can resume cleanly in a fresh session — and resumes from one when starting up.

This is not application code. It is a skill being authored and iterated on. The artifacts here are written to be installed into a user's `~/.claude/skills/` (or shipped as a `.skill` package), not run as a program.

## Layout

- `handoff/SKILL.md` — the skill itself (frontmatter + instructions). This is the only file that ships when packaged.
- `handoff-workspace/` — created on demand during iteration. Holds `iteration-N/` directories with eval runs, grading, and benchmark output. Not part of the shipped skill.
- `evals/evals.json` — test prompts used to evaluate the skill. Created when the iteration loop starts.

Git: initialized, tracking `origin` at https://github.com/pformoso-deus-ai/handoff-claude-skill (public). Default branch is `main`. No `.gitignore` yet — add one (e.g. for `handoff-workspace/` iteration output) when the iteration loop starts producing artifacts.

## How to develop the skill

The authoring workflow is driven by the `anthropic-skills:skill-creator` skill (already invoked once to scaffold this repo). The loop is:

1. Edit `handoff/SKILL.md`.
2. Write or update test prompts in `evals/evals.json`.
3. Spawn parallel subagent runs (one with the skill, one baseline without) for each prompt, saving outputs to `handoff-workspace/iteration-<N>/eval-<id>/`.
4. Grade outputs against assertions, aggregate into `benchmark.json`, and open the eval viewer for human review.
5. Read `feedback.json`, revise the skill, increment iteration, repeat.

Re-invoke `anthropic-skills:skill-creator` to drive this loop — it has the scripts and conventions baked in. Don't roll a custom test harness here.

### Packaging

When the skill is ready to ship, run the skill-creator's packaging script against `handoff/`. The output is a `.skill` file the user can install.

## Skill design notes

A few things about `handoff` that aren't obvious from reading SKILL.md cold:

- **The skill is dual-mode.** "Terminate" (write a handoff) and "resume" (read one and act) are intentionally one skill, not two. The triggering language and entry point are shared because the user's mental model is "the handoff thing" — splitting them risks one mode being undertriggered.
- **The handoff document format is load-bearing.** The Mode 2 (resume) path parses the headers from the doc Mode 1 wrote. Changing the template means changing both ends together. The template lives in SKILL.md under "Mode 1 → Step 3".
- **Verification commands are the linchpin.** A handoff doc is a snapshot; the world moves. The skill insists the writer include verification commands and insists the reader run them first. If a future revision removes that step, the resume path will silently act on stale assumptions.
- **No automatic git operations.** The user explicitly deferred git decisions. Do not add commit/push behavior to the skill or to repo tooling without checking first.

## Out of scope for now

- Git workflow (committing handoff docs, branch hygiene, etc.) — the user will revisit.
- A separate "summarize-only" mode — current scope is paused-work handoff, not session summaries.
- Persistence beyond `HANDOFF.md` in the working directory (e.g., a `~/.claude/handoffs/` archive).
