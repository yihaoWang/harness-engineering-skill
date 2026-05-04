#!/usr/bin/env bash
# install-hooks.sh — install/uninstall harness hooks into <project>/.claude/settings.json
#
# Hooks make harness "framework-like" — once installed, modes fire automatically:
#   SessionStart  → inject .harness/progress.md into context
#   Stop          → auto-handoff (writes new session entry to progress.md)
#   PostToolUse   → drift check after Edit/Write (standard+ levels)
#   UserPromptSubmit → ship reminder (aggressive level only)
#
# Usage:
#   install-hooks.sh [--level minimal|standard|aggressive]   # default: standard
#   install-hooks.sh --uninstall                              # remove only harness-managed hooks
#   install-hooks.sh --print                                  # show what would be written, no changes
#
# Idempotent: re-running upgrades cleanly. Only touches hooks tagged _harness_managed.
set -euo pipefail

LEVEL="standard"
ACTION="install"
while [ $# -gt 0 ]; do
  case "$1" in
    --level)     LEVEL="$2"; shift 2 ;;
    --uninstall) ACTION="uninstall"; shift ;;
    --print)     ACTION="print"; shift ;;
    *) shift ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SETTINGS="$ROOT/.claude/settings.json"
mkdir -p "$ROOT/.claude"

python3 - "$SETTINGS" "$LEVEL" "$ACTION" <<'PYEOF'
import json, os, sys
path, level, action = sys.argv[1], sys.argv[2], sys.argv[3]

s = json.load(open(path)) if os.path.exists(path) else {}
hooks = s.setdefault("hooks", {})

TAG = "_harness_managed"

# Strip existing harness-managed hooks (idempotent reinstall + clean uninstall)
for kind in list(hooks.keys()):
    hooks[kind] = [h for h in hooks[kind] if not h.get(TAG)]
    if not hooks[kind]:
        del hooks[kind]

LIB = "~/.claude/skills/harness/lib"

def make_hooks(level):
    out = [
        ("SessionStart", {
            "command": "cat .harness/progress.md 2>/dev/null | head -80 || true",
            TAG: True,
            "_purpose": "load last session state into context"
        }),
        ("Stop", {
            "command": f"{LIB}/handoff.sh --auto 2>/dev/null || true",
            TAG: True,
            "_purpose": "auto-handoff: append session entry to progress.md"
        }),
    ]
    if level in ("standard", "aggressive"):
        out.append(("PostToolUse", {
            "matcher": "Edit|Write",
            "command": (
                f"{LIB}/verify-features.sh 2>/dev/null | "
                "python3 -c \"import sys,json;"
                "d=json.load(sys.stdin);"
                "n=d.get('drift_count',0);"
                "print(f'\\u26a0\\ufe0f harness: {n} feature(s) drifted') if n else None\" "
                "2>/dev/null || true"
            ),
            TAG: True,
            "_purpose": "warn when an Edit causes a feature to drift from declared status"
        }))
    if level == "aggressive":
        out.append(("UserPromptSubmit", {
            "command": (
                "grep -qiE '(完成|done|ship|merge|done\\.|finished)' <<<\"$CLAUDE_USER_INPUT\" 2>/dev/null "
                "&& echo '💡 harness: about to ship? consider /harness-evaluate first' >&2 || true"
            ),
            TAG: True,
            "_purpose": "remind to run evaluate when user signals completion"
        }))
    return out

planned = []
if action != "uninstall":
    planned = make_hooks(level)
    for kind, hook in planned:
        hooks.setdefault(kind, []).append(hook)

# Clean up empty hooks key
if not hooks:
    s.pop("hooks", None)

result = {
    "action": action,
    "level": level if action != "uninstall" else None,
    "settings_path": path,
    "hooks_installed": [k for k, _ in planned] if action != "uninstall" else [],
}

if action == "print":
    result["preview_settings_json"] = s
elif action in ("install", "uninstall"):
    json.dump(s, open(path, "w"), indent=2)
    result["written"] = True

print(json.dumps(result, ensure_ascii=False, indent=2))
PYEOF
