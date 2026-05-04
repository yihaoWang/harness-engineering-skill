---
name: harness-evaluate
description: Run an independent evaluator sub-agent against project artifacts (UI / code diff / writing / i18n) using a configured rubric. Returns Accept / Revise / Block with evidence. Use when user says "評估 UI / 評估這段 code / 跑 evaluator / verify 這個產出". Core mechanism for fighting [[過早完成宣告]]: the generator agent never self-evaluates.
---

Read `~/.claude/skills/harness/SKILL.md` for shared rules and startup checks, then read `~/.claude/skills/harness/modes/evaluate.md` for this mode's procedure. Follow both.

ARGUMENTS: required — evaluator kind (`ui` / `code` / `writing` / `i18n` / custom name from `.harness/config.json`).
