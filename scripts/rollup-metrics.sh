#!/usr/bin/env bash
# AOS — Rollup metrics from actual file state
# Usage: ./scripts/rollup-metrics.sh [--json]
# Counts tasks, pipeline stages, accounts from the filesystem.
# The orchestrator agent can call this to get accurate metrics.

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON_MODE="${1:-}"

# Count tasks by status folder
tasks_inbox=$(find "${AREA_ROOT}/tasks/inbox" -name "TASK-*.md" 2>/dev/null | wc -l | tr -d ' ')
tasks_doing=$(find "${AREA_ROOT}/tasks/doing" -name "TASK-*.md" 2>/dev/null | wc -l | tr -d ' ')
tasks_review=$(find "${AREA_ROOT}/tasks/review" -name "TASK-*.md" 2>/dev/null | wc -l | tr -d ' ')
tasks_done=$(find "${AREA_ROOT}/tasks/done" -name "TASK-*.md" 2>/dev/null | wc -l | tr -d ' ')
tasks_total=$((tasks_inbox + tasks_doing + tasks_review + tasks_done))

# Count accounts
accounts_total=$(find "${AREA_ROOT}/accounts" -name "overview.md" 2>/dev/null | wc -l | tr -d ' ')

# Count pipeline stages from overview.md frontmatter (grep score field)
hot=0; warm=0; cold=0; no_score=0
for overview in "${AREA_ROOT}"/accounts/*/overview.md; do
    [[ -f "$overview" ]] || continue
    score=$(grep -m1 "^score:" "$overview" 2>/dev/null | sed 's/score: *//' | tr -d ' "')
    if [[ -z "$score" || "$score" == "-" || "$score" == "null" ]]; then
        no_score=$((no_score + 1))
    elif [[ "$score" -ge 70 ]]; then
        hot=$((hot + 1))
    elif [[ "$score" -ge 50 ]]; then
        warm=$((warm + 1))
    else
        cold=$((cold + 1))
    fi
done

# Count pending handoffs
handoffs_pending=$(find "${AREA_ROOT}/handoffs" -maxdepth 1 -name "HO-*.md" 2>/dev/null | wc -l | tr -d ' ')
handoffs_processed=$(find "${AREA_ROOT}/handoffs/processed" -name "HO-*.md" 2>/dev/null | wc -l | tr -d ' ')

# Today's log entries
today=$(date +%Y-%m-%d)
log_today=$(grep -c "\[.*\]" "${AREA_ROOT}/state/LOG.md" 2>/dev/null || echo "0")

if [[ "$JSON_MODE" == "--json" ]]; then
    cat << JSON_EOF
{
  "date": "${today}",
  "tasks": {
    "inbox": ${tasks_inbox},
    "doing": ${tasks_doing},
    "review": ${tasks_review},
    "done": ${tasks_done},
    "total": ${tasks_total}
  },
  "pipeline": {
    "accounts": ${accounts_total},
    "hot": ${hot},
    "warm": ${warm},
    "cold": ${cold},
    "unscored": ${no_score}
  },
  "handoffs": {
    "pending": ${handoffs_pending},
    "processed": ${handoffs_processed}
  }
}
JSON_EOF
else
    echo "=== AOS Metrics Rollup (${today}) ==="
    echo ""
    echo "Tasks:"
    echo "  inbox:  ${tasks_inbox}"
    echo "  doing:  ${tasks_doing}"
    echo "  review: ${tasks_review}"
    echo "  done:   ${tasks_done}"
    echo "  total:  ${tasks_total}"
    echo ""
    echo "Pipeline:"
    echo "  accounts: ${accounts_total}"
    echo "  hot (70+): ${hot}"
    echo "  warm (50-69): ${warm}"
    echo "  cold (<50): ${cold}"
    echo "  unscored: ${no_score}"
    echo ""
    echo "Handoffs:"
    echo "  pending:   ${handoffs_pending}"
    echo "  processed: ${handoffs_processed}"
fi
