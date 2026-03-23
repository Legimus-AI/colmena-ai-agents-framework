#!/usr/bin/env bash
# Colmena — Automated maintenance: prune, archive, clean
# Usage: ./scripts/maintenance.sh [--dry-run]
#
# What it does:
# 1. Archives tasks in done/ older than 7 days → tasks/archive/YYYY-MM.md
# 2. Deletes processed handoffs older than 3 days
# 3. Trims working-memory.md files > 50 lines (overflow → run-log.md)
# 4. Rotates run-log.md and LOG.md > 150 lines → archive

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN="${1:-}"
TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)

log() { echo "[maintenance] $1"; }
dry() { [[ "$DRY_RUN" == "--dry-run" ]] && echo "  (dry-run) $1" && return 0 || return 1; }

log "=== Colmena Maintenance (${TODAY}) ==="

# --- 1. Archive old done tasks ---
log "Checking tasks/done/ for tasks older than 7 days..."
ARCHIVE_FILE="${AREA_ROOT}/tasks/archive/${MONTH}.md"
archived=0

for task in "${AREA_ROOT}"/tasks/done/TASK-*.md; do
    [[ -f "$task" ]] || continue
    # Get file modification time (days ago)
    if [[ "$(uname)" == "Darwin" ]]; then
        file_age=$(( ( $(date +%s) - $(stat -f "%m" "$task") ) / 86400 ))
    else
        file_age=$(( ( $(date +%s) - $(stat -c "%Y" "$task") ) / 86400 ))
    fi

    if [[ $file_age -ge 7 ]]; then
        taskname=$(basename "$task")
        if dry "Would archive: ${taskname}"; then continue; fi

        log "Archiving: ${taskname} (${file_age} days old)"
        # Append task content to monthly archive
        if [[ ! -f "$ARCHIVE_FILE" ]]; then
            echo "# Archived Tasks — ${MONTH}" > "$ARCHIVE_FILE"
            echo "" >> "$ARCHIVE_FILE"
        fi
        echo "---" >> "$ARCHIVE_FILE"
        echo "## ${taskname} (archived ${TODAY})" >> "$ARCHIVE_FILE"
        echo "" >> "$ARCHIVE_FILE"
        cat "$task" >> "$ARCHIVE_FILE"
        echo "" >> "$ARCHIVE_FILE"
        rm "$task"
        archived=$((archived + 1))
    fi
done
log "Archived ${archived} done tasks."

# --- 2. Clean processed handoffs older than 3 days ---
log "Checking handoffs/processed/ for handoffs older than 3 days..."
cleaned_ho=0

for ho in "${AREA_ROOT}"/handoffs/processed/HO-*.md; do
    [[ -f "$ho" ]] || continue
    if [[ "$(uname)" == "Darwin" ]]; then
        file_age=$(( ( $(date +%s) - $(stat -f "%m" "$ho") ) / 86400 ))
    else
        file_age=$(( ( $(date +%s) - $(stat -c "%Y" "$ho") ) / 86400 ))
    fi

    if [[ $file_age -ge 3 ]]; then
        honame=$(basename "$ho")
        if dry "Would delete: ${honame}"; then continue; fi
        log "Deleting processed handoff: ${honame} (${file_age} days old)"
        rm "$ho"
        cleaned_ho=$((cleaned_ho + 1))
    fi
done
log "Cleaned ${cleaned_ho} processed handoffs."

# --- 3. Trim working-memory.md files > 50 lines ---
log "Checking agent working-memory.md files..."
trimmed=0

for wm in "${AREA_ROOT}"/agents/*/working-memory.md; do
    [[ -f "$wm" ]] || continue
    lines=$(wc -l < "$wm" | tr -d ' ')
    if [[ $lines -gt 50 ]]; then
        agent_dir=$(dirname "$wm")
        agent_name=$(basename "$agent_dir")
        overflow=$((lines - 50))

        if dry "Would trim ${agent_name}/working-memory.md (${lines} lines → 50, ${overflow} lines to run-log)"; then continue; fi

        log "Trimming ${agent_name}/working-memory.md: ${lines} → 50 lines (${overflow} overflow → run-log.md)"

        # Append overflow to run-log (lines 51+)
        run_log="${agent_dir}/run-log.md"
        echo "" >> "$run_log"
        echo "## Overflow from working-memory.md (${TODAY})" >> "$run_log"
        tail -n +"51" "$wm" >> "$run_log"

        # Keep only first 50 lines
        head -n 50 "$wm" > "${wm}.tmp"
        mv "${wm}.tmp" "$wm"
        trimmed=$((trimmed + 1))
    fi
done
log "Trimmed ${trimmed} working-memory files."

# --- 4. Rotate run-log.md and LOG.md > 150 lines ---
log "Checking log rotation..."
rotated=0

# Agent run-logs
for rl in "${AREA_ROOT}"/agents/*/run-log.md; do
    [[ -f "$rl" ]] || continue
    lines=$(wc -l < "$rl" | tr -d ' ')
    if [[ $lines -gt 150 ]]; then
        agent_dir=$(dirname "$rl")
        agent_name=$(basename "$agent_dir")
        archive="${agent_dir}/run-log-archive-${MONTH}.md"

        if dry "Would rotate ${agent_name}/run-log.md (${lines} lines)"; then continue; fi

        log "Rotating ${agent_name}/run-log.md: ${lines} lines → archive"
        mv "$rl" "$archive"
        echo "# Run Log — ${agent_name}" > "$rl"
        echo "" >> "$rl"
        echo "<!-- Previous entries archived to run-log-archive-${MONTH}.md -->" >> "$rl"
        rotated=$((rotated + 1))
    fi
done

# Area LOG.md
area_log="${AREA_ROOT}/state/LOG.md"
if [[ -f "$area_log" ]]; then
    lines=$(wc -l < "$area_log" | tr -d ' ')
    if [[ $lines -gt 150 ]]; then
        archive="${AREA_ROOT}/state/LOG-archive-${MONTH}.md"
        if ! dry "Would rotate state/LOG.md (${lines} lines)"; then
            log "Rotating state/LOG.md: ${lines} lines → archive"
            mv "$area_log" "$archive"
            echo "# Activity Log" > "$area_log"
            echo "" >> "$area_log"
            echo "<!-- Previous entries archived to LOG-archive-${MONTH}.md -->" >> "$area_log"
            rotated=$((rotated + 1))
        fi
    fi
fi

log "Rotated ${rotated} log files."
log "=== Maintenance complete ==="
