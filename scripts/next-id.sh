#!/usr/bin/env bash
# AOS — Atomic task ID generator
# Returns the next available TASK ID and increments the counter.
# Usage: scripts/next-id.sh → prints "TASK-008" (example)
# The orchestrator MUST use this when creating tasks.

set -euo pipefail
AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ID_FILE="${AREA_ROOT}/.next-id"

if [[ ! -f "$ID_FILE" ]]; then
    echo "1" > "$ID_FILE"
fi

CURRENT=$(cat "$ID_FILE" | tr -d '[:space:]')
NEXT=$((CURRENT + 1))
echo "$NEXT" > "$ID_FILE"

printf "TASK-%03d" "$CURRENT"
