#!/usr/bin/env bash
# Colmena — Health check / Dead Man's Snitch (Jarvis OS)
# Detects if the area has gone silent (no agent activity) or has infrastructure issues.
# Sends Telegram alert if problems found.
#
# Usage: scripts/health-check.sh [--max-silence-hours N] [--notify-url URL]
# Environment: NOTIFY_URL, MAX_SILENCE_HOURS (defaults: 4h)

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAX_SILENCE_HOURS="${MAX_SILENCE_HOURS:-4}"
NOTIFY_URL="${NOTIFY_URL:-}"
issues=()

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-silence-hours) MAX_SILENCE_HOURS="$2"; shift 2 ;;
        --notify-url) NOTIFY_URL="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "=== Health Check ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="

now_epoch=$(date +%s)

# --- 1. Check LOG.md for last activity ---
echo "[1] Checking last activity in LOG.md..."
log_file="${AREA_ROOT}/state/LOG.md"
if [[ -f "$log_file" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        log_epoch=$(stat -f "%m" "$log_file")
    else
        log_epoch=$(stat -c "%Y" "$log_file")
    fi
    silence_hours=$(( (now_epoch - log_epoch) / 3600 ))
    if [[ $silence_hours -ge $MAX_SILENCE_HOURS ]]; then
        echo "  ALERT: No activity for ${silence_hours}h (threshold: ${MAX_SILENCE_HOURS}h)"
        issues+=("Area offline: no LOG.md updates for ${silence_hours}h")
    else
        echo "  OK: Last activity ${silence_hours}h ago"
    fi
else
    echo "  ALERT: LOG.md not found"
    issues+=("LOG.md missing — area may not be initialized")
fi

# --- 2. Check for stale lockfiles ---
echo "[2] Checking for stale lockfiles..."
for lockfile in "${AREA_ROOT}"/.lock-*; do
    [[ -f "$lockfile" ]] || continue
    agent_name=$(basename "$lockfile" | sed 's/^\.lock-//')
    lock_pid=$(cat "$lockfile" 2>/dev/null || echo "0")
    if ! kill -0 "$lock_pid" 2>/dev/null; then
        echo "  ALERT: Stale lockfile for '${agent_name}' (PID ${lock_pid} is dead)"
        issues+=("Stale lock: ${agent_name} (PID ${lock_pid} dead)")
    else
        echo "  OK: ${agent_name} running (PID ${lock_pid})"
    fi
done

# --- 3. Check disk space ---
echo "[3] Checking disk space..."
if command -v df &> /dev/null; then
    # Get available space in KB for the partition containing AREA_ROOT
    avail_kb=$(df -k "$AREA_ROOT" | tail -1 | awk '{print $4}')
    avail_mb=$((avail_kb / 1024))
    if [[ $avail_mb -lt 1024 ]]; then
        echo "  ALERT: Low disk space: ${avail_mb}MB available"
        issues+=("Low disk: ${avail_mb}MB available")
    else
        echo "  OK: ${avail_mb}MB available"
    fi
fi

# --- 4. Check critical files exist ---
echo "[4] Checking critical files..."
critical_files=(
    "CLAUDE.md"
    "state/STATE.md"
    "state/LOG.md"
    "state/QUEUE.md"
    "state/OBJECTIVES.md"
    "scripts/validate.sh"
)
for f in "${critical_files[@]}"; do
    if [[ ! -f "${AREA_ROOT}/${f}" ]]; then
        echo "  ALERT: Missing critical file: ${f}"
        issues+=("Missing: ${f}")
    fi
done
echo "  OK: All critical files present"

# --- Summary ---
echo ""
echo "Issues found: ${#issues[@]}"

if [[ ${#issues[@]} -eq 0 ]]; then
    echo "Area is healthy."
    exit 0
fi

# --- Send notification ---
if [[ -n "$NOTIFY_URL" ]] && command -v curl &> /dev/null; then
    issue_text=$(printf '%s\n' "${issues[@]}" | head -5)
    message="[Colmena Health] ${#issues[@]} issues:
${issue_text}"
    curl -s -X POST "$NOTIFY_URL" \
        -H "Content-Type: application/json" \
        -d "{\"message\": $(echo "$message" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"${message}\"")}" \
        > /dev/null 2>&1 || true
    echo "Notification sent."
elif [[ -z "$NOTIFY_URL" ]]; then
    echo "WARN: No NOTIFY_URL configured. Set via --notify-url or NOTIFY_URL env var."
fi

exit 1
