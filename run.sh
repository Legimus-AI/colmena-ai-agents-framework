#!/bin/bash
# AOS — Area Operating System: Agent Runner
# Usage: ./run.sh <agent-name> [--dry-run]
#
# Agents: orchestrator, researcher, writer, closer
# Example: ./run.sh orchestrator
#          ./run.sh researcher --dry-run

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")" && pwd)"
AGENT="${1:-}"
DRY_RUN="${2:-}"

if [[ -z "$AGENT" ]]; then
    echo "Usage: ./run.sh <agent-name> [--dry-run]"
    echo ""
    echo "Available agents:"
    echo "  orchestrator  — Plan, assign, review, consolidate"
    echo "  researcher    — Investigate prospects"
    echo "  writer        — Write outreach sequences"
    echo "  closer        — Prepare demos, handle objections"
    echo ""
    echo "Options:"
    echo "  --dry-run     Show the prompt that would be sent (don't execute)"
    exit 1
fi

AGENT_DIR="${AREA_ROOT}/agents/${AGENT}"

if [[ ! -d "$AGENT_DIR" ]]; then
    echo "ERROR: Agent '${AGENT}' not found at ${AGENT_DIR}"
    exit 1
fi

# --- Concurrency guard (C3 fix) ---
LOCKFILE="${AREA_ROOT}/.lock-${AGENT}"
if [[ -f "$LOCKFILE" ]]; then
    LOCK_PID=$(cat "$LOCKFILE" 2>/dev/null || echo "unknown")
    LOCK_TIME=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$LOCKFILE" 2>/dev/null || echo "unknown")
    echo "ERROR: Agent '${AGENT}' is already running (PID: ${LOCK_PID}, since: ${LOCK_TIME})"
    echo "If this is stale, remove: rm ${LOCKFILE}"
    exit 1
fi
trap 'rm -f "$LOCKFILE"' EXIT
echo $$ > "$LOCKFILE"

# --- Tool restrictions per agent (C2 fix) ---
declare -A AGENT_TOOLS
AGENT_TOOLS[orchestrator]="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*)"
AGENT_TOOLS[researcher]="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*),WebSearch,WebFetch"
AGENT_TOOLS[writer]="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*)"
AGENT_TOOLS[closer]="Read,Write,Edit,Glob,Grep,Bash(mv:*),Bash(ls:*),Bash(date:*),WebSearch,WebFetch"

TOOLS="${AGENT_TOOLS[$AGENT]:-Read,Write,Glob,Grep}"

# --- Build prompt (C1 fix: use heredoc + pipe, not shell argument) ---
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
If you try to write outside your scope, your write will be blocked.

TASK CLAIMING: When you pick a task from tasks/inbox/, IMMEDIATELY move it to tasks/doing/ BEFORE starting work. This prevents other agents from picking the same task.
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
    echo ""
    echo "=== COMMAND ==="
    echo "cd ${AREA_ROOT} && echo '<prompt>' | claude -p --allowedTools \"${TOOLS}\""
    exit 0
fi

echo "Starting agent: ${AGENT}"
echo "Working dir: ${AREA_ROOT}"
echo "Allowed tools: ${TOOLS}"
echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "---"

cd "${AREA_ROOT}"
echo "$PROMPT" | claude -p --allowedTools "$TOOLS"

echo "---"
echo "Agent '${AGENT}' session completed at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
