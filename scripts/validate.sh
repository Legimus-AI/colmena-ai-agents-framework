#!/usr/bin/env bash
# Colmena — State validator and auto-fixer
# Checks the vault for inconsistencies and optionally fixes them.
#
# Usage: scripts/validate.sh [--fix]

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX_MODE="${1:-}"
errors=0
fixed=0

warn() { echo "  WARN: $1"; errors=$((errors + 1)); }
ok() { echo "  OK: $1"; }
fix() { echo "  FIX: $1"; fixed=$((fixed + 1)); }

echo "=== Colmena State Validation ==="
echo ""

# --- 1. Check for duplicate tasks across status folders ---
echo "[1] Checking for duplicate tasks..."
for task in "${AREA_ROOT}"/tasks/*/TASK-*.md; do
    [[ -f "$task" ]] || continue
    taskname=$(basename "$task")
    # Count how many folders have this task
    count=$(find "${AREA_ROOT}/tasks" -maxdepth 2 -name "$taskname" -not -path "*/archive/*" -not -path "*/_templates/*" | wc -l | tr -d ' ')
    if [[ $count -gt 1 ]]; then
        warn "Duplicate task: ${taskname} found in ${count} folders"
        if [[ "$FIX_MODE" == "--fix" ]]; then
            # Keep the most advanced status version: done > approval > review > doing > inbox
            for status in done approval review doing inbox; do
                if [[ -f "${AREA_ROOT}/tasks/${status}/${taskname}" ]]; then
                    # Keep this one, remove all others
                    for other_status in done approval review doing inbox; do
                        if [[ "$other_status" != "$status" && -f "${AREA_ROOT}/tasks/${other_status}/${taskname}" ]]; then
                            rm "${AREA_ROOT}/tasks/${other_status}/${taskname}"
                            fix "Removed duplicate ${taskname} from ${other_status}/ (kept in ${status}/)"
                        fi
                    done
                    # Update frontmatter to match folder
                    sed -i '' "s/^status: .*/status: ${status}/" "${AREA_ROOT}/tasks/${status}/${taskname}" 2>/dev/null
                    break
                fi
            done
        fi
    fi
done
[[ $errors -eq 0 ]] && ok "No duplicate tasks found"

# --- 2. Check frontmatter status matches folder ---
echo "[2] Checking frontmatter status consistency..."
prev_errors=$errors
for status_dir in inbox doing review approval done; do
    for task in "${AREA_ROOT}/tasks/${status_dir}"/TASK-*.md; do
        [[ -f "$task" ]] || continue
        taskname=$(basename "$task")
        fm_status=$(grep -m1 "^status:" "$task" 2>/dev/null | sed 's/status: *//' | tr -d ' "' || echo "")
        if [[ -n "$fm_status" && "$fm_status" != "$status_dir" ]]; then
            warn "${taskname}: frontmatter says '${fm_status}' but file is in '${status_dir}/'"
            if [[ "$FIX_MODE" == "--fix" ]]; then
                sed -i '' "s/^status: .*/status: ${status_dir}/" "$task"
                fix "Updated ${taskname} frontmatter to '${status_dir}'"
            fi
        fi
    done
done
[[ $errors -eq $prev_errors ]] && ok "All frontmatter statuses match folders"

# --- 3. Check for orphaned handoffs (no matching task) ---
echo "[3] Checking for orphaned handoffs..."
prev_errors=$errors
for ho in "${AREA_ROOT}"/handoffs/HO-*.md; do
    [[ -f "$ho" ]] || continue
    honame=$(basename "$ho")
    task_ref=$(grep -m1 "^task:" "$ho" 2>/dev/null | sed 's/task: *//' | tr -d ' "' || echo "")
    if [[ -n "$task_ref" ]]; then
        task_exists=$(find "${AREA_ROOT}/tasks" -name "${task_ref}*" -not -path "*/archive/*" | head -1)
        if [[ -z "$task_exists" ]]; then
            warn "Handoff ${honame} references task '${task_ref}' which doesn't exist"
        fi
    fi
done
[[ $errors -eq $prev_errors ]] && ok "All handoffs reference valid tasks"

# --- 4. Check for stale tasks in doing/ (no lock = agent not running) ---
echo "[4] Checking for stalled tasks in doing/..."
prev_errors=$errors
for task in "${AREA_ROOT}"/tasks/doing/TASK-*.md; do
    [[ -f "$task" ]] || continue
    taskname=$(basename "$task")
    owner=$(grep -m1 "^owner:" "$task" 2>/dev/null | sed 's/owner: *//' | tr -d ' "' || echo "")
    if [[ -n "$owner" ]]; then
        lockfile="${AREA_ROOT}/.lock-${owner}"
        if [[ ! -f "$lockfile" ]]; then
            warn "Task ${taskname} is in doing/ but agent '${owner}' is not running (no lockfile)"
        fi
    fi
done
[[ $errors -eq $prev_errors ]] && ok "No stalled tasks (all doing/ tasks have active agents)"

# --- 5. Check for overdue tasks ---
echo "[5] Checking for overdue tasks..."
prev_errors=$errors
today=$(date +%Y-%m-%d)
for status_dir in inbox doing review approval; do
    for task in "${AREA_ROOT}/tasks/${status_dir}"/TASK-*.md; do
        [[ -f "$task" ]] || continue
        taskname=$(basename "$task")
        due=$(grep -m1 "^due:" "$task" 2>/dev/null | sed 's/due: *//' | tr -d ' "' || echo "")
        if [[ -n "$due" && "$due" < "$today" ]]; then
            warn "OVERDUE: ${taskname} was due ${due} (today: ${today}), status: ${status_dir}"
        fi
    done
done
[[ $errors -eq $prev_errors ]] && ok "No overdue tasks"

# --- 6. Check QUEUE.md matches actual tasks ---
echo "[6] Checking QUEUE.md consistency..."
queue_file="${AREA_ROOT}/state/QUEUE.md"
if [[ -f "$queue_file" ]]; then
    # Count task IDs mentioned in QUEUE vs actual task files
    queue_ids=$(grep -oE "TASK-[0-9]+" "$queue_file" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    actual_ids=$(find "${AREA_ROOT}/tasks" -name "TASK-*.md" -not -path "*/archive/*" -not -path "*/_templates/*" | xargs -I{} basename {} | grep -oE "TASK-[0-9]+" | sort -u | wc -l | tr -d ' ')
    if [[ "$queue_ids" -ne "$actual_ids" ]]; then
        warn "QUEUE.md references ${queue_ids} tasks but ${actual_ids} task files exist"
    else
        ok "QUEUE.md task count matches filesystem (${actual_ids} tasks)"
    fi
else
    warn "QUEUE.md not found"
fi

# --- 7. Check agent working-memory.md size ---
echo "[7] Checking agent memory sizes..."
prev_errors=$errors
for wm in "${AREA_ROOT}"/agents/*/working-memory.md; do
    [[ -f "$wm" ]] || continue
    agent_name=$(basename "$(dirname "$wm")")
    lines=$(wc -l < "$wm" | tr -d ' ')
    if [[ $lines -gt 50 ]]; then
        warn "${agent_name}/working-memory.md is ${lines} lines (max 50)"
    fi
done
[[ $errors -eq $prev_errors ]] && ok "All working-memory files within limits"

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "Errors found: ${errors}"
if [[ "$FIX_MODE" == "--fix" ]]; then
    echo "Auto-fixed: ${fixed}"
fi
if [[ $errors -gt 0 && "$FIX_MODE" != "--fix" ]]; then
    echo "Run with --fix to auto-repair: scripts/validate.sh --fix"
fi

exit $([[ $errors -eq 0 ]] && echo 0 || echo 1)
