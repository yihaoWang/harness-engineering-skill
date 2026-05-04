---
name: harness-promote-lesson
description: Convert a recurring agent mistake into a permanent guardrail (lint rule / test / pre-commit hook / AGENTS.md entry). Use when user says "這錯不要再犯 / 把這條規則永久執行 / promote this lesson". Avoids the trap of repeatedly fixing the same class of error by making it mechanically impossible to repeat.
---

Read `~/.claude/skills/harness/SKILL.md` for shared rules and startup checks, then read `~/.claude/skills/harness/modes/promote-lesson.md` for this mode's procedure. Follow both.

ARGUMENTS: optional — describe the lesson, e.g. "renderer 不能直接 import fs". If absent, ask user to describe the recurring mistake.
