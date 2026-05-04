---
name: harness-bootstrap
description: Bootstrap harness engineering for a code project. Detects stack (npm/pnpm/cargo/python), generates .harness/config.json with discovered commands, creates progress.md / feature_list.json templates, adds a CLAUDE.md section pointing to the harness skill. Use when user says "初始化 harness / harness bootstrap / 為這 project 設計 harness". One-time per project.
---

Read `~/.claude/skills/harness/SKILL.md` for shared rules and startup checks, then read `~/.claude/skills/harness/modes/bootstrap.md` for this mode's procedure. Follow both.

ARGUMENTS: optional — `--minimal` to skip ui detection, just generate base 4 files.
