#!/usr/bin/env bash
# Colmena — Daily status digest (Jarvis OS)
# Generates a short status summary and sends via notification channel.
# Customize the data sources for your area (CRM API, rollup-metrics, etc.)
#
# Usage: scripts/generate-daily-status.sh [--notify-url URL]
# Environment: NOTIFY_URL

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOTIFY_URL="${NOTIFY_URL:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notify-url) NOTIFY_URL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# --- Get metrics from rollup ---
metrics=$(bash "${AREA_ROOT}/scripts/rollup-metrics.sh" --json 2>/dev/null || echo "{}")
hot=$(echo "$metrics" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pipeline',{}).get('hot','?'))" 2>/dev/null || echo "?")
warm=$(echo "$metrics" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pipeline',{}).get('warm','?'))" 2>/dev/null || echo "?")
accounts=$(echo "$metrics" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pipeline',{}).get('accounts','?'))" 2>/dev/null || echo "?")

# --- Approval count ---
approval_count=$(find "${AREA_ROOT}/tasks/approval" -name "TASK-*.md" 2>/dev/null | wc -l | tr -d ' ')

# --- North Star from OBJECTIVES.md ---
ns_current=$(grep -A2 "north_star:" "${AREA_ROOT}/state/OBJECTIVES.md" 2>/dev/null | grep "current:" | head -1 | sed 's/.*current: *//' | tr -d ' ' || echo "?")
ns_target=$(grep -A3 "north_star:" "${AREA_ROOT}/state/OBJECTIVES.md" 2>/dev/null | grep "target:" | head -1 | sed 's/.*target: *//' | tr -d ' ' || echo "?")

# --- Pending decisions ---
decisions=$(grep -c "^### " "${AREA_ROOT}/state/DECISION_QUEUE.md" 2>/dev/null || echo "0")

# --- Build message ---
area_name=$(basename "$AREA_ROOT")
msg="[Colmena ${area_name}] Daily Status
Pipeline: ${hot} hot, ${warm} warm, ${accounts} total | ${approval_count} approvals
North Star: ${ns_current}/${ns_target}
${decisions} decisions pending"

echo "$msg"

# --- Send notification ---
if [[ -n "$NOTIFY_URL" ]] && command -v curl &> /dev/null; then
    payload=$(python3 -c "import json; print(json.dumps({'message': '''$msg'''}))" 2>/dev/null || echo "{\"message\": \"Daily status\"}")
    curl -sf -X POST "$NOTIFY_URL" -H "Content-Type: application/json" -d "$payload" > /dev/null 2>&1 || true
    echo "Notification sent."
fi
