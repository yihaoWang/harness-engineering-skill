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

Two steps — clone the skill **and** symlink the slash commands:

```bash
# 1. Clone the skill
git clone https://github.com/yihaoWang/harness-engineering-skill.git ~/.claude/skills/harness

# 2. Register slash commands (/harness-bootstrap, /harness-handoff, /harness-promote-lesson, /harness-evaluate)
mkdir -p ~/.claude/commands
ln -s ~/.claude/skills/harness/commands/*.md ~/.claude/commands/
```

Why two steps: Claude Code auto-discovers skills under `~/.claude/skills/` and slash commands under `~/.claude/commands/`. The skill provides the logic; the commands provide the `/harness-*` entry points. Symlinking means a `git pull` on the skill auto-updates both.

The skill folder **must** be named `harness` (not `harness-engineering-skill`) — the skill name needs to match.

No restart needed; Claude Code picks both up automatically.

## Usage

### 1. First time in a project — bootstrap

```bash
cd ~/your-project
```

In Claude Code, either say:

> 初始化 harness  /  initialize harness for this project

…or run the slash command:

```
/harness-bootstrap
```

Claude will:

1. Read your `package.json` / `Cargo.toml` / `pyproject.toml` / etc. to detect the stack
2. Show you the detected `commands` + `ui.framework` and ask you to confirm
3. Write `.harness/{config.json, progress.md, feature_list.json, lessons.md}` and append a section to your `CLAUDE.md`

Then commit:

```bash
git add .harness/ CLAUDE.md
git commit -m "chore: bootstrap harness"
```

### 2. Framework mode (default — set by bootstrap)

Bootstrap installs hooks into `<project>/.claude/settings.json` so harness runs **automatically** without you remembering slash commands. Three opt-in levels:

| Level | Hooks installed | Effect |
|---|---|---|
| **minimal** | `SessionStart` + `Stop` | Last session state injected at start; auto-handoff at end. |
| **standard** *(default)* | + `PostToolUse: Edit\|Write` | Above, plus drift warning when an edit breaks a declared-passing feature. |
| **aggressive** | + `UserPromptSubmit` reminder | Above, plus a nudge to run `/harness-evaluate` when you say "done" / "ship". |

To pick a level (or change later):

```bash
~/.claude/skills/harness/lib/install-hooks.sh --level standard   # default
~/.claude/skills/harness/lib/install-hooks.sh --level minimal    # quieter
~/.claude/skills/harness/lib/install-hooks.sh --level aggressive # most active
~/.claude/skills/harness/lib/install-hooks.sh --uninstall        # remove only harness hooks (others untouched)
~/.claude/skills/harness/lib/install-hooks.sh --print            # dry-run
```

To skip hook install at bootstrap: `~/.claude/skills/harness/lib/bootstrap.sh --apply --no-hooks --config '<json>'`.

### 3. Manual override — slash commands

For when you want to trigger a mode explicitly (or test it):

| Goal | Slash command |
|---|---|
| Force a session handoff right now | `/harness-handoff` |
| Promote a recurring mistake into a permanent guardrail | `/harness-promote-lesson` |
| Evaluate UI / code / writing with an independent sub-agent | `/harness-evaluate <kind>` |
| Re-run bootstrap (e.g., adjust config or hook level) | `/harness-bootstrap` |

You should rarely need these in normal use — the hooks fire on the right events.

### 4. Seed your `feature_list.json`

After bootstrap, open `.harness/feature_list.json` and add the features your project already has, with **runnable** evidence:

```json
{
  "features": [
    {
      "id": "user-auth",
      "status": "passing",
      "evidence": {
        "command": "npm test -- auth.spec.ts",
        "expected_exit": 0,
        "safe": true
      }
    },
    {
      "id": "db-schema-deployed",
      "status": "passing",
      "evidence": {
        "command": "npm run db:check",
        "expected_exit": 0,
        "safe": false,
        "verified_at": "2026-05-04T10:00:00Z"
      }
    }
  ]
}
```

`safe: true` (default) = re-runnable any time. `safe: false` = needs env / mutates state / long-running — verified at write-time and stamped with `verified_at`.

Then to detect drift any time:

```bash
~/.claude/skills/harness/lib/verify-features.sh         # safe-only (fast)
~/.claude/skills/harness/lib/verify-features.sh --full  # include unsafe (slow, before release)
```

### 5. Custom rubrics for `evaluate` (optional)

Write project-specific rubrics in `.harness/rubrics/`:

- `ui.md` — visual quality criteria for your design system
- `code.md` — code review criteria for your codebase
- `writing.md` — doc / spec quality criteria

If a rubric is missing, `evaluate` falls back to a built-in default. A starter `ui.md` ships with the skill at `~/.claude/skills/harness/rubrics/ui.md` — copy it into your project and edit.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `/harness-bootstrap` not found | Either skill cloned to wrong path (must be `~/.claude/skills/harness/`), or you skipped step 2 of install — symlink commands into `~/.claude/commands/`. Verify: `ls ~/.claude/commands/harness-*.md`. |
| Bootstrap detects wrong stack | Tell Claude the correct stack/commands; it will pass them as `--config '<json>'` to `bootstrap.sh`. |
| `verify-features.sh` says drift but you didn't change anything | Either an `evidence.command` is non-deterministic (flaky test), or the `expected_exit` is wrong. Fix the evidence, not the code. |
| Handoff Stop hook doesn't fire | Check `~/.claude/settings.json` — the hook may not be installed. Re-run `/update-config`. |

## Status

MVP. Scripts pass syntax check; not yet battle-tested on a real project. Untested:

- `bootstrap.sh --apply` end-to-end on a fresh project
- Stop hook integration for auto-handoff
- `evaluate` mode with real sub-agent dispatch
- `promote-lesson` lint rule installation across eslint / ruff / clippy

Issues and PRs welcome.

## License

MIT
