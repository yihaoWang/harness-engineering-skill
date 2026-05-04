---
name: harness-handoff
description: Write session handoff to .harness/progress.md so the next session can resume without re-discovering. Updates "current state / completed this session / in progress / blockers / next step". Use when user says "收尾 / handoff / 寫 progress / 結束 session" or auto-triggered by Stop hook.
---

Read `~/.claude/skills/harness/SKILL.md` for shared rules and startup checks, then read `~/.claude/skills/harness/modes/handoff.md` for this mode's procedure. Follow both.

ARGUMENTS: optional — `--auto` (called from hook, no user prompt) | `--summary` for one-line summary instead of full update.
