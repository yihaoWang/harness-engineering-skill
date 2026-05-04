#!/usr/bin/env bash
# verify-features.sh — re-run evidence commands in feature_list.json
# By default skips evidence with `safe: false` (long-running, mutating, requires-env).
# Pass --full to run them all.
#
# Evidence schema:
#   evidence: {
#     command: "...",
#     expected_exit: 0,
#     safe: true|false   # default true; false = needs env / mutates state / long-running
#     verified_at: "ISO" # only meaningful when safe=false (when was this last manually checked)
#   }
#
# Output JSON includes per-feature: declared_status, current_result, drift, skipped_unsafe.
# Exit 0 if no drift among checked, 1 if drift, 2 if config missing.
set -euo pipefail

FULL=0
[ "${1:-}" = "--full" ] && FULL=1

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FL="$ROOT/.harness/feature_list.json"
[ -f "$FL" ] || { echo "{\"error\":\"no feature_list at $FL\"}"; exit 2; }

cd "$ROOT"
python3 - "$FL" "$FULL" <<'PYEOF'
import json, subprocess, sys
from datetime import datetime, timezone

fl_path = sys.argv[1]
full = sys.argv[2] == "1"
data = json.load(open(fl_path))

drift_count = 0
skipped_unsafe = 0
results = []

for f in data.get("features", []):
    ev = f.get("evidence")
    if isinstance(ev, dict) and ev.get("command"):
        cmd = ev["command"]
        expected_exit = ev.get("expected_exit", 0)
        safe = ev.get("safe", True)
        if not safe and not full:
            skipped_unsafe += 1
            results.append({
                "id": f.get("id"),
                "declared_status": f.get("status"),
                "evidence_command": cmd,
                "skipped": "unsafe (use --full to run)",
                "verified_at": ev.get("verified_at"),
            })
            continue
        try:
            r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
            actual_exit = r.returncode
        except subprocess.TimeoutExpired:
            actual_exit = -1
        current = "pass" if actual_exit == expected_exit else "fail"
        drift = (f.get("status") == "passing" and current == "fail") or \
                (f.get("status") not in ("passing",) and current == "pass")
        if drift:
            drift_count += 1
        results.append({
            "id": f.get("id"),
            "declared_status": f.get("status"),
            "evidence_command": cmd,
            "expected_exit": expected_exit,
            "actual_exit": actual_exit,
            "current_result": current,
            "drift": drift,
            "safe": safe,
        })
    else:
        results.append({
            "id": f.get("id"),
            "declared_status": f.get("status"),
            "evidence_command": None,
            "warning": "evidence is prose or missing — cannot machine-verify",
        })

out = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "mode": "full" if full else "safe-only",
    "total": len(data.get("features", [])),
    "machine_verifiable": sum(1 for r in results if r.get("evidence_command")),
    "skipped_unsafe": skipped_unsafe,
    "drift_count": drift_count,
    "features": results,
}
print(json.dumps(out, ensure_ascii=False, indent=2))
sys.exit(0 if drift_count == 0 else 1)
PYEOF
