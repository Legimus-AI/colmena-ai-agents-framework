#!/usr/bin/env bash
# AOS — Sync PIPELINE.md from accounts/*/overview.md
# Regenerates the pipeline table from actual account data.
# Usage: scripts/sync-pipeline.sh

set -euo pipefail
AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIPELINE="${AREA_ROOT}/shared/PIPELINE.md"

cat > "$PIPELINE" << 'HEADER'
# Sales Pipeline — Ventas

## Stages

| Stage | Description | Exit Criteria |
|-------|------------|---------------|
| Cold | Identified, not contacted | Research complete + score assigned |
| Warm | Contacted, awaiting response | Response received |
| Hot | Engaged, demo scheduled or in negotiation | Demo done or proposal sent |
| Won | Deal closed | Payment received |
| Lost | Deal lost | Reason documented |

## Current Pipeline

| Prospect | Stage | Score | Decision Maker | Next Action | Last Update |
|----------|-------|-------|----------------|-------------|-------------|
HEADER

for overview in "${AREA_ROOT}"/accounts/*/overview.md; do
    [[ -f "$overview" ]] || continue
    slug=$(basename "$(dirname "$overview")")

    company=$(grep -m1 "^company:" "$overview" 2>/dev/null | sed 's/company: *//' | tr -d '"' || echo "$slug")
    score=$(grep -m1 "^score:" "$overview" 2>/dev/null | sed 's/score: *//' | tr -d ' "' || echo "-")
    dm_name=$(grep -m1 "name:" "$overview" 2>/dev/null | head -1 | sed 's/.*name: *//' | tr -d '"' || echo "PENDING")
    dm_role=$(grep -m1 "role:" "$overview" 2>/dev/null | head -1 | sed 's/.*role: *//' | tr -d '"' || echo "")
    next=$(grep -m1 "^recommended_next:" "$overview" 2>/dev/null | sed 's/recommended_next: *//' | tr -d '"' || echo "-")
    date=$(grep -m1 "^researched_at:" "$overview" 2>/dev/null | sed 's/researched_at: *//' | tr -d ' "' || echo "-")

    # Determine stage from score
    if [[ "$score" == "-" || "$score" == "null" ]]; then
        stage="Cold"
    elif [[ "$score" -ge 70 ]]; then
        stage="Hot"
    elif [[ "$score" -ge 50 ]]; then
        stage="Warm"
    else
        stage="Cold"
    fi

    dm="${dm_name}"
    [[ -n "$dm_role" ]] && dm="${dm_name}, ${dm_role}"

    echo "| ${company} | ${stage} | ${score} | ${dm} | ${next} | ${date} |" >> "$PIPELINE"
done

echo ""
echo "Pipeline synced from $(find "${AREA_ROOT}/accounts" -name "overview.md" | wc -l | tr -d ' ') accounts."
