#!/usr/bin/env bash
# Colmena — Atomic task mover
# Moves a task file between status folders AND updates the YAML frontmatter status.
# This is the ONLY correct way to change a task's status.
#
# Usage: scripts/move-task.sh <task-filename> <from-status> <to-status>
# Example: scripts/move-task.sh TASK-001-research.md inbox doing
#
# Valid statuses: inbox, doing, review, approval, done

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TASK_FILE="${1:-}"
FROM="${2:-}"
TO="${3:-}"

VALID_STATUSES="inbox doing review approval done"

if [[ -z "$TASK_FILE" || -z "$FROM" || -z "$TO" ]]; then
    echo "Usage: scripts/move-task.sh <task-filename> <from-status> <to-status>"
    echo "Example: scripts/move-task.sh TASK-001.md inbox doing"
    echo "Valid statuses: ${VALID_STATUSES}"
    exit 1
fi

# Validate statuses
if ! echo "$VALID_STATUSES" | grep -qw "$FROM"; then
    echo "ERROR: Invalid from-status '${FROM}'. Valid: ${VALID_STATUSES}"
    exit 1
fi
if ! echo "$VALID_STATUSES" | grep -qw "$TO"; then
    echo "ERROR: Invalid to-status '${TO}'. Valid: ${VALID_STATUSES}"
    exit 1
fi

SOURCE="${AREA_ROOT}/tasks/${FROM}/${TASK_FILE}"
DEST="${AREA_ROOT}/tasks/${TO}/${TASK_FILE}"

if [[ ! -f "$SOURCE" ]]; then
    echo "ERROR: Task file not found: ${SOURCE}"
    exit 1
fi

if [[ -f "$DEST" ]]; then
    echo "ERROR: Destination already has this file: ${DEST}"
    echo "This likely means a duplicate exists. Run scripts/validate.sh to fix."
    exit 1
fi

# Update status in YAML frontmatter
if grep -q "^status:" "$SOURCE"; then
    sed -i '' "s/^status: .*/status: ${TO}/" "$SOURCE"
fi

# Move the file
mv "$SOURCE" "$DEST"

echo "OK: ${TASK_FILE} moved ${FROM} → ${TO}"
