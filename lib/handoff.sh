#!/usr/bin/env bash
# handoff.sh — collect session state for progress.md update
# Usage:
#   handoff.sh                     # collect, output JSON (no write)
#   handoff.sh --append <yaml>     # append a session record (yaml block from stdin or arg)
#   handoff.sh --query last        # query last session frontmatter
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/.harness/config.json"
PROGRESS="$ROOT/.harness/progress.md"

[ -f "$CONFIG" ] || { echo '{"error":"no .harness/config.json — run bootstrap first"}'; exit 2; }

MODE="${1:-collect}"

case "$MODE" in
  --query)
    [ -f "$PROGRESS" ] || { echo '{"error":"no progress.md"}'; exit 2; }
    # extract last YAML frontmatter block
    python3 - "$PROGRESS" <<'PYEOF'
import sys, re, json
content = open(sys.argv[1]).read()
blocks = re.findall(r'^---\n(.*?)\n---', content, re.MULTILINE | re.DOTALL)
if not blocks:
    print(json.dumps({"last_session": None}))
else:
    # parse simple yaml (key: value, key: [list])
    last = blocks[-1]
    out = {}
    for line in last.split("\n"):
        m = re.match(r'^(\w+):\s*(.*)$', line)
        if m:
            k, v = m.group(1), m.group(2).strip()
            if v.startswith("[") and v.endswith("]"):
                v = [x.strip().strip('"').strip("'") for x in v[1:-1].split(",") if x.strip()]
            out[k] = v
    print(json.dumps({"last_session": out}, ensure_ascii=False))
PYEOF
    ;;
  --append)
    BLOCK="${2:?yaml block required after --append}"
    mkdir -p "$(dirname "$PROGRESS")"
    [ -f "$PROGRESS" ] || echo "# Progress" > "$PROGRESS"
    {
      echo
      echo "---"
      echo "$BLOCK"
      echo "---"
      echo
    } >> "$PROGRESS"
    echo "{\"appended\": true, \"file\": \"$PROGRESS\"}"
    ;;
  *)
    # collect mode — output what we know, don't write
    cd "$ROOT"
    TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('commands',{}).get('test',''))")
    python3 - "$ROOT" "$TEST_CMD" <<'PYEOF'
import json, os, subprocess, sys
from datetime import datetime, timezone

root, test_cmd = sys.argv[1], sys.argv[2]
os.chdir(root)

def run(cmd, **kw):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120, **kw)
    except subprocess.TimeoutExpired:
        return None

git_log = run("git log --oneline -10")
git_status = run("git status --porcelain")
head = run("git rev-parse --short HEAD")

out = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "head": head.stdout.strip() if head and head.returncode == 0 else None,
    "recent_commits": git_log.stdout.strip().split("\n") if git_log and git_log.returncode == 0 else [],
    "dirty_files": [l[3:] for l in git_status.stdout.strip().split("\n") if l] if git_status and git_status.stdout else [],
    "test_command": test_cmd,
    "test_result": None,
}

if test_cmd:
    r = run(test_cmd)
    if r:
        out["test_result"] = {"exit": r.returncode, "stdout_tail": r.stdout[-500:], "stderr_tail": r.stderr[-500:]}
    else:
        out["test_result"] = {"exit": -1, "error": "timeout"}

# next-step heuristic
if out["dirty_files"]:
    out["next_step_hint"] = f"finish work-in-progress on {len(out['dirty_files'])} dirty files"
elif out["test_result"] and out["test_result"].get("exit", 0) != 0:
    out["next_step_hint"] = "fix failing tests before adding features"
else:
    # check feature_list for in_progress / not_started
    fl = os.path.join(root, ".harness/feature_list.json")
    if os.path.exists(fl):
        d = json.load(open(fl))
        ip = [f for f in d.get("features", []) if f.get("status") == "in_progress"]
        ns = sorted([f for f in d.get("features", []) if f.get("status") == "not_started"], key=lambda x: x.get("priority", 99))
        if ip:
            out["next_step_hint"] = f"continue feature {ip[0]['id']}"
        elif ns:
            out["next_step_hint"] = f"start feature {ns[0]['id']}"
        else:
            out["next_step_hint"] = "all features in passing/blocked state — pick new work"
    else:
        out["next_step_hint"] = "no feature_list.json — bootstrap or define features"

print(json.dumps(out, ensure_ascii=False, indent=2))
PYEOF
    ;;
esac
