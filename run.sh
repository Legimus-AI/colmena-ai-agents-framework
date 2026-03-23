#!/usr/bin/env bash
# Colmena — Area Operating System: Agent Runner
# Usage: ./run.sh <agent-name> [--dry-run]

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")" && pwd)"
AGENT="${1:-}"
DRY_RUN="${2:-}"
LOGS_DIR="${AREA_ROOT}/logs"

if [[ -z "$AGENT" ]]; then
    echo "Usage: ./run.sh <agent-name> [--dry-run]"
    echo ""
    echo "Available agents:"
    for d in "${AREA_ROOT}"/agents/*/; do
        [[ -d "$d" ]] && echo "  $(basename "$d")"
    done
    echo ""
    echo "Other commands:"
    echo "  ./run-cycle.sh              Run full agent cycle (orchestrator→researcher→writer→closer→orchestrator)"
    echo "  ./scripts/validate.sh       Check vault consistency"
    echo "  ./scripts/rollup-metrics.sh Show current metrics"
    echo "  ./scripts/maintenance.sh    Archive old tasks, prune memory"
    exit 1
fi

AGENT_DIR="${AREA_ROOT}/agents/${AGENT}"
if [[ ! -d "$AGENT_DIR" ]]; then
    echo "ERROR: Agent '${AGENT}' not found at ${AGENT_DIR}"
    exit 1
fi

# --- Stale lock detection ---
LOCKFILE="${AREA_ROOT}/.lock-${AGENT}"
if [[ -f "$LOCKFILE" ]]; then
    LOCK_PID=$(cat "$LOCKFILE" 2>/dev/null || echo "0")
    if kill -0 "$LOCK_PID" 2>/dev/null; then
        LOCK_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LOCKFILE" 2>/dev/null || echo "unknown")
        echo "ERROR: Agent '${AGENT}' is already running (PID: ${LOCK_PID}, since: ${LOCK_TIME})"
        exit 1
    else
        echo "WARN: Removing stale lockfile (PID ${LOCK_PID} is dead)"
        rm -f "$LOCKFILE"
    fi
fi
trap 'rm -f "$LOCKFILE"' EXIT
echo $$ > "$LOCKFILE"

# --- Tool restrictions per agent ---
MCP_EXTRA=""
case "$AGENT" in
    orchestrator)
        TOOLS="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*),Bash(bash:*),Bash(find:*),Bash(wc:*),Bash(cat:*),Bash(grep:*),Bash(sed:*)"
        ;;
    researcher)
        TOOLS="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*),Bash(bash:*),Bash(sed:*),WebSearch,WebFetch"
        # Researcher needs browser MCP servers for deep research
        MCP_EXTRA="--mcp-config ${AREA_ROOT}/mcp-config.json"
        ;;
    writer)
        TOOLS="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*),Bash(bash:*),Bash(sed:*)"
        ;;
    closer)
        TOOLS="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*),Bash(bash:*),Bash(sed:*),WebSearch,WebFetch"
        MCP_EXTRA="--mcp-config ${AREA_ROOT}/mcp-config.json"
        ;;
    *)
        TOOLS="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(bash:*)"
        ;;
esac

# --- Build prompt ---
PROMPT=$(cat <<PROMPT_EOF
You are the '${AGENT}' agent in the Legimus AI Sales team.

Your working directory is: ${AREA_ROOT}

CRITICAL: Follow your session protocol EXACTLY as described in your CLAUDE.md.

Step 1: Read the area rules at CLAUDE.md (the file in the root of your working directory)
Step 2: Read your agent instructions at agents/${AGENT}/CLAUDE.md
Step 3: Read your personal state at agents/${AGENT}/working-memory.md
Step 4: Read the area state at state/STATE.md
Step 5: Execute your session protocol — find and work on your assigned tasks.
Step 6: Before ending, complete your session end protocol (update working-memory, run-log, LOG.md).

BOUNDARIES: You can ONLY write to the directories specified in your CLAUDE.md boundaries section.

MOVING TASKS: To move a task between status folders, ALWAYS use the helper script:
  bash scripts/move-task.sh <filename> <from-status> <to-status>
Example: bash scripts/move-task.sh TASK-001-research.md inbox doing
This is the ONLY correct way to move tasks. NEVER copy files manually between folders.

HANDOFF PROCESSING: After reading a handoff from handoffs/, move it to handoffs/processed/:
  mv handoffs/HO-001.md handoffs/processed/HO-001.md
PROMPT_EOF
)

if [[ "$DRY_RUN" == "--dry-run" ]]; then
    echo "=== DRY RUN ==="
    echo "Agent: ${AGENT}"
    echo "Working dir: ${AREA_ROOT}"
    echo "Allowed tools: ${TOOLS}"
    echo ""
    echo "=== PROMPT ==="
    echo "$PROMPT"
    exit 0
fi

# --- Setup logging ---
mkdir -p "$LOGS_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
AGENT_LOG="${LOGS_DIR}/${AGENT}-${TIMESTAMP}.log"

echo "Starting agent: ${AGENT}"
echo "Working dir: ${AREA_ROOT}"
echo "Allowed tools: ${TOOLS}"
echo "Log: ${AGENT_LOG}"
echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "---"

# --- Run agent with output capture ---
cd "${AREA_ROOT}"
# shellcheck disable=SC2086
echo "$PROMPT" | claude -p --allowedTools "$TOOLS" $MCP_EXTRA 2>&1 | tee "$AGENT_LOG"

echo "---"
echo "Agent '${AGENT}' session completed at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Post-run validation (auto-fix duplicates) ---
echo ""
echo "--- Post-run validation ---"
bash "${AREA_ROOT}/scripts/validate.sh" --fix 2>&1 || true

# --- Notify Victor if tasks landed in approval/ ---
approval_count=$(find "${AREA_ROOT}/tasks/approval" -name "TASK-*.md" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$approval_count" -gt 0 ]]; then
    echo ""
    echo "*** ${approval_count} task(s) awaiting Victor's approval in tasks/approval/ ***"
    approval_list=$(ls "${AREA_ROOT}/tasks/approval/TASK-"*.md 2>/dev/null | xargs -I{} basename {} | tr '\n' ', ' | sed 's/,$//')
    # Send Telegram notification if curl is available
    NOTIFY_URL="https://api-notifications.legimus.ai/api/telegram_ghost_caller/41918720-d3af-4857-a753-815ed991058f/send"
    if command -v curl &> /dev/null; then
        curl -s -X POST "$NOTIFY_URL" \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"[Colmena Ventas] ${approval_count} task(s) need your approval: ${approval_list}\"}" \
            > /dev/null 2>&1 || true
        echo "  Telegram notification sent."
    fi
fi
