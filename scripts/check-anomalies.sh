#!/usr/bin/env bash
# Colmena — Anomaly detection and alerting (Jarvis OS)
# Checks for stale approvals, stalled tasks, off-track objectives, and validation errors.
# Sends Telegram notification only for critical (red) items.
#
# Usage: scripts/check-anomalies.sh [--notify-url URL]
# Environment: NOTIFY_URL (fallback if --notify-url not provided)

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAST_ALERT_FILE="${AREA_ROOT}/.last-anomaly-alert"
ALERT_COOLDOWN_HOURS=4
STALE_APPROVAL_HOURS="${STALE_APPROVAL_HOURS:-48}"
STALE_DOING_HOURS="${STALE_DOING_HOURS:-24}"
alerts=()

# --- Parse args ---
NOTIFY_URL="${NOTIFY_URL:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --notify-url) NOTIFY_URL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== Anomaly Check ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="

# --- 1. Stale approvals (tasks in approval/ for too long) ---
echo "[1] Checking stale approvals (>${STALE_APPROVAL_HOURS}h)..."
now_epoch=$(date +%s)
for task in "${AREA_ROOT}"/tasks/approval/TASK-*.md; do
    [[ -f "$task" ]] || continue
    taskname=$(basename "$task")
    # Use file modification time as proxy for when it entered approval/
    if [[ "$(uname)" == "Darwin" ]]; then
        file_epoch=$(stat -f "%m" "$task")
    else
        file_epoch=$(stat -c "%Y" "$task")
    fi
    age_hours=$(( (now_epoch - file_epoch) / 3600 ))
    if [[ $age_hours -ge $STALE_APPROVAL_HOURS ]]; then
        echo "  ALERT: ${taskname} has been in approval/ for ${age_hours}h"
        alerts+=("Stale approval: ${taskname} (${age_hours}h)")
    fi
done

# --- 2. Stalled tasks in doing/ (no recent LOG.md mention) ---
echo "[2] Checking stalled tasks in doing/..."
for task in "${AREA_ROOT}"/tasks/doing/TASK-*.md; do
    [[ -f "$task" ]] || continue
    taskname=$(basename "$task")
    task_id=$(echo "$taskname" | grep -oE "TASK-[0-9]+")
    # Check if task ID appears in recent LOG.md entries
    if [[ -f "${AREA_ROOT}/state/LOG.md" ]]; then
        last_mention=$(grep -n "$task_id" "${AREA_ROOT}/state/LOG.md" | tail -1 | cut -d: -f1 || echo "0")
        if [[ "$last_mention" == "0" || -z "$last_mention" ]]; then
            echo "  ALERT: ${taskname} in doing/ with no LOG.md mention"
            alerts+=("Stalled task: ${taskname} (never logged)")
        fi
    fi
done

# --- 3. Objectives off-track ---
echo "[3] Checking objectives..."
objectives_file="${AREA_ROOT}/state/OBJECTIVES.md"
if [[ -f "$objectives_file" ]]; then
    ns_current=$(grep -m1 "^  current:" "$objectives_file" 2>/dev/null | sed 's/.*current: *//' | tr -d ' "' || echo "0")
    ns_target=$(grep -m1 "^  target:" "$objectives_file" 2>/dev/null | sed 's/.*target: *//' | tr -d ' "' || echo "0")
    if [[ "$ns_target" -gt 0 ]] 2>/dev/null; then
        pct=$(( ns_current * 100 / ns_target ))
        if [[ $pct -lt 50 ]]; then
            echo "  ALERT: North Star at ${pct}% of target (${ns_current}/${ns_target})"
            alerts+=("North Star critical: ${ns_current}/${ns_target} (${pct}%)")
        fi
    fi
fi

# --- 4. Validation errors ---
echo "[4] Running validate.sh..."
if bash "${AREA_ROOT}/scripts/validate.sh" > /dev/null 2>&1; then
    echo "  OK: Validation passed"
else
    echo "  ALERT: Validation has errors"
    alerts+=("Validation errors detected")
fi

# --- Summary ---
echo ""
echo "Alerts found: ${#alerts[@]}"

if [[ ${#alerts[@]} -eq 0 ]]; then
    echo "All clear."
    exit 0
fi

# --- Check cooldown (avoid spamming) ---
should_notify=true
if [[ -f "$LAST_ALERT_FILE" ]]; then
    last_alert_epoch=$(cat "$LAST_ALERT_FILE" 2>/dev/null || echo "0")
    elapsed_hours=$(( (now_epoch - last_alert_epoch) / 3600 ))
    if [[ $elapsed_hours -lt $ALERT_COOLDOWN_HOURS ]]; then
        echo "Skipping notification (last alert ${elapsed_hours}h ago, cooldown ${ALERT_COOLDOWN_HOURS}h)"
        should_notify=false
    fi
fi

# --- Send notification ---
if [[ "$should_notify" == true && -n "$NOTIFY_URL" ]] && command -v curl &> /dev/null; then
    alert_text=$(printf '%s\n' "${alerts[@]}" | head -5)
    message="[Colmena] ${#alerts[@]} anomalies detected:
${alert_text}"
    curl -s -X POST "$NOTIFY_URL" \
        -H "Content-Type: application/json" \
        -d "{\"message\": $(echo "$message" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"${message}\"")}" \
        > /dev/null 2>&1 || true
    echo "Notification sent."
    echo "$now_epoch" > "$LAST_ALERT_FILE"
elif [[ "$should_notify" == true && -z "$NOTIFY_URL" ]]; then
    echo "WARN: No NOTIFY_URL configured. Set via --notify-url or NOTIFY_URL env var."
fi

exit 1
