# harness-engineering-skill

A Claude Code skill that bootstraps and maintains **harness engineering** for any code project — the outer layer of tools, rules, and conventions that lets an LLM agent execute real engineering work reliably.

> Inspired by [walkinglabs/learn-harness-engineering](https://github.com/walkinglabs/learn-harness-engineering). This skill is a 2.0 take: walkinglabs builds for "human + naive Claude"; this skill builds for "Claude as orchestrator."

## Design principle

**Deterministic → script. Judgment → LLM.**

Anything that has a single correct answer (parsing JSON, writing scaffold files, re-running a command and comparing exit codes) is a `lib/*.sh` script. Anything that needs taste (picking which lint rule fits, summarizing a session goal, evaluating UI quality) stays in `modes/*.md` for the LLM.

This is the opposite of bloated mode markdown that walks the LLM through deterministic steps line-by-line — that wastes tokens and adds non-determinism where there shouldn't be any.

## The 4 modes

Each mode targets a specific failure pattern that breaks long-running agent work:

| Mode | Triggers | Solves |
|---|---|---|
| **bootstrap** | "initialize harness for this project" | Project scaffold + `.harness/config.json` + `CLAUDE.md` integration. One-time. |
| **handoff** | end of session, or Stop hook | Cross-session amnesia. Writes `progress.md` so next session resumes cleanly. |
| **promote-lesson** | "this mistake again — make it permanent" | Repeated mistakes. Routes lesson to lint > test > pre-commit > docs (strongest available wins). |
| **evaluate** | "evaluate this UI / code / writing" | Premature completion claims. Spawns an **independent evaluator sub-agent** that runs a rubric and returns Accept / Revise / Block with evidence. |

The generator agent never self-evaluates — that's the whole point of the `evaluate` mode.

## Repo layout

```
harness/
├── SKILL.md                # Entry point: mode dispatch table + startup checks
├── modes/
│   ├── bootstrap.md
│   ├── handoff.md
│   ├── promote-lesson.md
│   └── evaluate.md
├── lib/
│   ├── bootstrap.sh        # Scaffold writer (LLM provides detection JSON)
│   ├── handoff.sh          # collect / append / query session state
│   ├── verify-features.sh  # Re-run evidence commands (safe filter + --full)
│   └── clean-state-check.sh
├── rubrics/
│   └── ui.md               # Starter rubric for `evaluate ui`
├── bootstrap/SKILL.md      # /harness-bootstrap dispatcher
├── handoff/SKILL.md        # /harness-handoff
├── promote-lesson/SKILL.md
└── evaluate/SKILL.md       # /harness-evaluate <kind>
```

## Per-project artifacts (`.harness/`)

After `/harness-bootstrap`, each project gets:

```
<project>/.harness/
├── config.json          # commands, ui framework, evaluator rubric paths
├── progress.md          # session log (YAML frontmatter, machine-queryable)
├── feature_list.json    # features with verifiable evidence
├── lessons.md           # promoted lessons + how each is enforced
├── rubrics/             # per-project evaluator rubrics
└── evaluations/         # archived evaluator reports
```

## Key design choices vs walkinglabs

| Topic | walkinglabs | this skill |
|---|---|---|
| Stack detection | written into `init.sh` per project | LLM reads manifests; `bootstrap.sh` writes scaffold |
| Evidence | prose ("verified by running tests") | `{command, expected_exit, safe, verified_at}` — re-runnable |
| `progress.md` | prose | YAML frontmatter + prose; `handoff.sh --query` parses |
| Cross-project reuse | copy-paste then edit | one shared skill, per-project config |
| Evaluator | not a primitive | first-class `evaluate` mode + rubric registry |

### `safe` flag on evidence

Every evidence command declares `safe: true|false`:

- `safe: true` (default): re-runnable any time. `verify-features.sh` runs these on every check.
- `safe: false`: requires environment / mutates state / long-running (db migrate, dev server, e2e). Skipped by default; `--full` includes them. LLM must verify once at write-time and stamp `verified_at`.

This separates "cheap truth" from "expensive truth" — both are tracked, neither pretends to be the other.

## Install

Drop the directory under `~/.claude/skills/`:

```bash
git clone https://github.com/yihaoWang/harness-engineering-skill.git ~/.claude/skills/harness
```

Then in any project: `/harness-bootstrap` → confirm detected stack → done.

## Status

MVP. Scripts pass syntax check; not yet battle-tested on a real project. Untested:

- `bootstrap.sh --apply` end-to-end on a fresh project
- Stop hook integration for auto-handoff
- `evaluate` mode with real sub-agent dispatch
- `promote-lesson` lint rule installation across eslint / ruff / clippy

Issues and PRs welcome.

## License

MIT
