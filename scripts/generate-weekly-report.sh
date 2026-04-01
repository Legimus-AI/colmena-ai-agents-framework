#!/usr/bin/env bash
# Colmena — Weekly AREA Report generator (Jarvis OS)
# Generates a CEO-facing weekly report using the template in rhythm/templates/weekly-report.md.
#
# Usage: scripts/generate-weekly-report.sh [--notify-url URL]
# Environment: NOTIFY_URL

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEEK_NUM=$(date +%V)
YEAR=$(date +%Y)
REPORT_DIR="${AREA_ROOT}/rhythm/weekly"
REPORT_FILE="${REPORT_DIR}/${YEAR}-W${WEEK_NUM}.md"
NOTIFY_URL="${NOTIFY_URL:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notify-url) NOTIFY_URL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

mkdir -p "$REPORT_DIR"

# --- Get metrics ---
metrics=$(bash "${AREA_ROOT}/scripts/rollup-metrics.sh" --json 2>/dev/null || echo "{}")
hot=$(echo "$metrics" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pipeline',{}).get('hot','?'))" 2>/dev/null || echo "?")
warm=$(echo "$metrics" | python3 -c "import sys,json; print(json.load(sys.stdin).get('pipeline',{}).get('warm','?'))" 2>/dev/null || echo "?")
tasks_done=$(echo "$metrics" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tasks',{}).get('done','0'))" 2>/dev/null || echo "0")

# --- Get objectives ---
ns_metric=$(grep "metric:" "${AREA_ROOT}/state/OBJECTIVES.md" 2>/dev/null | head -1 | sed 's/.*metric: *"//' | sed 's/".*//' || echo "?")
ns_current=$(grep -A2 "north_star:" "${AREA_ROOT}/state/OBJECTIVES.md" 2>/dev/null | grep "current:" | head -1 | sed 's/.*current: *//' | tr -d ' ' || echo "?")
ns_target=$(grep -A3 "north_star:" "${AREA_ROOT}/state/OBJECTIVES.md" 2>/dev/null | grep "target:" | head -1 | sed 's/.*target: *//' | tr -d ' ' || echo "?")

# --- Pending decisions ---
decisions=$(grep -c "^### " "${AREA_ROOT}/state/DECISION_QUEUE.md" 2>/dev/null || echo "0")

# --- Autonomy level ---
level=$(grep "^level:" "${AREA_ROOT}/state/AUTONOMY_LEVEL.md" 2>/dev/null | head -1 | sed 's/level: *//' || echo "1")
level_name=$(grep "^level_name:" "${AREA_ROOT}/state/AUTONOMY_LEVEL.md" 2>/dev/null | head -1 | sed 's/level_name: *"//' | sed 's/".*//' || echo "Aprendiz")

# --- Recent learnings ---
learnings=$(tail -20 "${AREA_ROOT}/shared/LEARNINGS.md" 2>/dev/null | grep "^-" | tail -3 || echo "- No new learnings")

# --- Area name ---
area_name=$(basename "$AREA_ROOT")

# --- Generate report ---
cat > "$REPORT_FILE" << REPORT
# AREA REPORT — ${area_name} — Week ${WEEK_NUM} (${YEAR})

## North Star
**${ns_metric}**
Current: ${ns_current} / Target: ${ns_target}

## Pipeline
- Hot: ${hot} | Warm: ${warm}
- Tasks completed: ${tasks_done}

## Decision Queue
${decisions} items pending CEO input.

## Autonomy Level: ${level} (${level_name})

## Learnings
${learnings}

---
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
REPORT

echo "Weekly report: $REPORT_FILE"

# --- Send summary via notification ---
if [[ -n "$NOTIFY_URL" ]] && command -v curl &> /dev/null; then
    msg="[Colmena ${area_name}] Weekly Report W${WEEK_NUM} | NS: ${ns_current}/${ns_target} | ${hot} hot, ${warm} warm | ${decisions} decisions | L${level} ${level_name}"
    payload=$(python3 -c "import json; print(json.dumps({'message': '''$msg'''}))" 2>/dev/null || echo "{\"message\": \"Weekly report generated\"}")
    curl -sf -X POST "$NOTIFY_URL" -H "Content-Type: application/json" -d "$payload" > /dev/null 2>&1 || true
    echo "Notification sent."
fi
