#!/usr/bin/env bash
# AOS — Run a full agent cycle in sequence
# Executes agents in the correct order, validates state between runs,
# and captures all output to logs.
#
# Usage: ./run-cycle.sh [agents...]
# Default: orchestrator → researcher → writer → closer → orchestrator (review)
#
# Examples:
#   ./run-cycle.sh                          # Full default cycle
#   ./run-cycle.sh orchestrator researcher  # Only these two
#   ./run-cycle.sh --validate-only          # Just run validation

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOGS_DIR="${AREA_ROOT}/logs"
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "${LOGS_DIR}"

# Default cycle order
if [[ $# -eq 0 ]]; then
    AGENTS=(orchestrator researcher writer closer orchestrator)
elif [[ "$1" == "--validate-only" ]]; then
    echo "Running validation only..."
    bash "${AREA_ROOT}/scripts/validate.sh" --fix
    exit $?
else
    AGENTS=("$@")
fi

CYCLE_LOG="${LOGS_DIR}/cycle-${TIMESTAMP}.md"

log() {
    echo "$1"
    echo "$1" >> "$CYCLE_LOG"
}

# --- Start cycle ---
cat > "$CYCLE_LOG" << EOF
# Cycle Log — ${TODAY} ${TIMESTAMP}

Agents: ${AGENTS[*]}

EOF

log "=== AOS Cycle Start: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
log "Agents to run: ${AGENTS[*]}"
log ""

# --- Pre-cycle validation ---
log "--- Pre-cycle validation ---"
bash "${AREA_ROOT}/scripts/validate.sh" --fix >> "$CYCLE_LOG" 2>&1 || true
log ""

cycle_ok=true
for agent in "${AGENTS[@]}"; do
    log "--- Running: ${agent} ---"
    AGENT_LOG="${LOGS_DIR}/${agent}-${TIMESTAMP}.log"

    start_time=$(date +%s)

    # Run the agent and capture output
    if bash "${AREA_ROOT}/run.sh" "$agent" > "$AGENT_LOG" 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log "  Status: OK (${duration}s)"
        log "  Output: ${AGENT_LOG}"

        # Extract the summary line from output (last paragraph before "Agent completed")
        summary=$(grep -B5 "session completed" "$AGENT_LOG" | head -3 | tr '\n' ' ' | sed 's/  */ /g')
        [[ -n "$summary" ]] && log "  Summary: ${summary}"
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log "  Status: FAILED (${duration}s)"
        log "  Output: ${AGENT_LOG}"
        cycle_ok=false

        # Check if task is stuck in doing/
        log "  Checking for stuck tasks..."
        for stuck in "${AREA_ROOT}"/tasks/doing/TASK-*.md; do
            [[ -f "$stuck" ]] || continue
            taskname=$(basename "$stuck")
            owner=$(grep -m1 "^owner:" "$stuck" 2>/dev/null | sed 's/owner: *//' | tr -d ' "' || echo "")
            if [[ "$owner" == "$agent" ]]; then
                log "  WARNING: ${taskname} stuck in doing/ — agent crashed. Moving back to inbox/."
                mv "$stuck" "${AREA_ROOT}/tasks/inbox/${taskname}"
                sed -i '' "s/^status: .*/status: inbox/" "${AREA_ROOT}/tasks/inbox/${taskname}" 2>/dev/null
            fi
        done
    fi

    # Post-agent validation
    log "  Post-run validation:"
    bash "${AREA_ROOT}/scripts/validate.sh" --fix >> "$CYCLE_LOG" 2>&1 || true
    log ""
done

# --- Post-cycle metrics ---
log "--- Post-cycle metrics ---"
bash "${AREA_ROOT}/scripts/rollup-metrics.sh" >> "$CYCLE_LOG" 2>&1

log ""
if $cycle_ok; then
    log "=== Cycle completed successfully at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
else
    log "=== Cycle completed WITH ERRORS at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
fi

log "Full log: ${CYCLE_LOG}"
