# handoff

A Claude Code skill that captures the state of a long session into a structured document, so a fresh session can pick up cleanly without re-deliberating from scratch.

## Install

**macOS / Linux**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pformoso-deus-ai/handoff-claude-skill/main/install.sh)"
```

**Windows (PowerShell)**

```powershell
iwr -useb https://raw.githubusercontent.com/pformoso-deus-ai/handoff-claude-skill/main/install.ps1 | iex
```

The installer copies the skill into `~/.claude/skills/handoff/` (or `$env:USERPROFILE\.claude\skills\handoff\` on Windows).

**First-time install**: restart Claude Code (or close and reopen any session) so the file watcher picks up the new skill directory. After that, edits to the skill hot-reload mid-session without a restart.

**Pin a version** by setting `HANDOFF_REF` to any branch, tag, or commit:

```bash
HANDOFF_REF=v0.1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/pformoso-deus-ai/handoff-claude-skill/main/install.sh)"
```

**Inspect before running** (recommended for any `curl | bash` pattern): the scripts are [install.sh](install.sh) and [install.ps1](install.ps1) in this repo. They download `handoff/SKILL.md` into the skills directory and print a restart hint if needed.

**Manual install** — if you'd rather skip the script, the skill is the single file `handoff/SKILL.md`. Copy it to `~/.claude/skills/handoff/SKILL.md` directly.

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

Re-run the same install command. The script overwrites `SKILL.md` with the latest from the pinned ref (default `main`); open Claude Code sessions hot-reload the change without a restart.
