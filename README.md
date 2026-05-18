# handoff

A Claude Code skill that captures the state of a long session into a structured document, so a fresh session can pick up cleanly without re-deliberating from scratch.

## Install

Copy the skill into your local Claude Code skills directory.

**macOS / Linux**

```bash
mkdir -p ~/.claude/skills/handoff
cp handoff/SKILL.md ~/.claude/skills/handoff/
```

**Windows (PowerShell)**

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills\handoff" | Out-Null
Copy-Item handoff\SKILL.md "$env:USERPROFILE\.claude\skills\handoff\"
```

Start a fresh Claude Code session — the skill is picked up automatically. Only `handoff/SKILL.md` ships; everything else in this repo is for authoring and iterating on the skill itself.

## Use

The skill has two modes, both triggered by what you say in chat. No flags, no per-project setup.

### End a session — write a handoff

When you want to stop now and resume later, say one of:

- `/handoff`
- "wrap this up so I can keep going tomorrow"
- "stop here for today"
- "context is filling up, save what we have"

Claude writes `HANDOFF.md` in the current working directory. The doc captures:

- the current goal (as it stands now, not the original ask if it drifted),
- where work was paused, with `file:line` references,
- decisions made and the rationale behind them,
- dead ends already explored, so they're not retried,
- verification commands to run when resuming,
- the next concrete step (a specific file and change, not "continue the feature").

By default no git operations run during the write — the handoff is decoupled from your commit history.

### Start a session — resume from a handoff

In a fresh session in the same directory, say one of:

- `/handoff`
- "pick up where we left off"
- "resume from handoff"
- "what was I working on"

Claude reads `HANDOFF.md` and runs the verification commands embedded in it (`git status`, your test command, etc.) **before any edits**. If state has drifted — different branch, broken tests, a cited line that no longer matches — Claude stops and surfaces what diverged rather than acting on stale assumptions.

If verification passes, you'll get a three-line acknowledgement (goal / current state / next action), then Claude continues from there.

## Updating

After pulling new changes from this repo:

```bash
cp handoff/SKILL.md ~/.claude/skills/handoff/
```

Restart any open Claude Code session for the new version to load.
