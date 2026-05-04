#!/usr/bin/env bash
# clean-state-check.sh — verify 5-dim clean exit (build/test/progress/artifact/startup)
# Output JSON. Exit 0 if all clean, 1 if any dim fails.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG="$ROOT/.harness/config.json"
[ -f "$CONFIG" ] || { echo '{"error":"no .harness/config.json"}'; exit 2; }

cd "$ROOT"
python3 - "$CONFIG" "$ROOT" <<'PYEOF'
import json, os, subprocess, sys, glob

cfg = json.load(open(sys.argv[1]))
root = sys.argv[2]
cmds = cfg.get("commands", {})

def run(cmd):
    if not cmd: return None
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=180)
        return {"exit": r.returncode, "tail": (r.stdout + r.stderr)[-300:]}
    except subprocess.TimeoutExpired:
        return {"exit": -1, "tail": "timeout"}

dims = {}

# 1. build
b = run(cmds.get("build") or cmds.get("check"))
dims["build"] = {"command": cmds.get("build") or cmds.get("check"), "result": b, "pass": b is None or b["exit"] == 0}

# 2. test
t = run(cmds.get("test"))
dims["test"] = {"command": cmds.get("test"), "result": t, "pass": t is None or t["exit"] == 0}

# 3. progress: file exists and updated within 7 days
import time
prog = os.path.join(root, ".harness/progress.md")
prog_ok = os.path.exists(prog) and (time.time() - os.path.getmtime(prog)) < 7 * 86400
dims["progress"] = {"path": ".harness/progress.md", "exists": os.path.exists(prog), "fresh_within_7d": prog_ok, "pass": prog_ok}

# 4. artifact: no debug remnants in tracked files
debug_patterns = ["console.log(", "debugger;", "TODO:", "FIXME:", "XXX:"]
git_diff = subprocess.run("git diff --name-only HEAD", shell=True, capture_output=True, text=True)
changed = [f for f in git_diff.stdout.strip().split("\n") if f]
debug_hits = []
for f in changed[:50]:  # cap
    fp = os.path.join(root, f)
    if not os.path.isfile(fp): continue
    try:
        content = open(fp).read()
        for p in debug_patterns:
            if p in content:
                debug_hits.append({"file": f, "pattern": p})
                break
    except Exception:
        pass
dims["artifact"] = {"changed_files": len(changed), "debug_hits": debug_hits, "pass": len(debug_hits) == 0}

# 5. startup: dev command exists in config
dev = cmds.get("dev")
dims["startup"] = {"dev_command": dev, "pass": bool(dev)}

failed = [k for k, v in dims.items() if not v.get("pass")]
out = {"dims": dims, "failed_dims": failed, "all_clean": len(failed) == 0}
print(json.dumps(out, ensure_ascii=False, indent=2))
sys.exit(0 if not failed else 1)
PYEOF
