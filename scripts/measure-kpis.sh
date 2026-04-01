#!/usr/bin/env bash
# Colmena — KPI measurement and tracking (Jarvis OS)
# Runs rollup-metrics.sh, parses OBJECTIVES.md, calculates health scores,
# updates current values in OBJECTIVES.md, and appends weekly snapshot to KPI_HISTORY.md.
#
# Usage: scripts/measure-kpis.sh [--force]
#   --force: Append weekly snapshot even if today is not Monday

set -euo pipefail

AREA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OBJECTIVES="${AREA_ROOT}/state/OBJECTIVES.md"
KPI_HISTORY="${AREA_ROOT}/state/KPI_HISTORY.md"
FORCE="${1:-}"

echo "=== KPI Measurement ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ==="

# --- 1. Get current metrics from rollup ---
echo "[1] Running metrics rollup..."
if [[ ! -f "${AREA_ROOT}/scripts/rollup-metrics.sh" ]]; then
    echo "ERROR: rollup-metrics.sh not found"
    exit 1
fi

metrics_json=$(bash "${AREA_ROOT}/scripts/rollup-metrics.sh" --json 2>/dev/null)
if [[ -z "$metrics_json" ]]; then
    echo "ERROR: rollup-metrics.sh returned empty output"
    exit 1
fi

# Parse metrics
tasks_done=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks']['done'])" 2>/dev/null || echo "0")
tasks_total=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks']['total'])" 2>/dev/null || echo "0")
tasks_inbox=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks']['inbox'])" 2>/dev/null || echo "0")
tasks_doing=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['tasks']['doing'])" 2>/dev/null || echo "0")
accounts=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['pipeline']['accounts'])" 2>/dev/null || echo "0")
hot=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['pipeline']['hot'])" 2>/dev/null || echo "0")
warm=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['pipeline']['warm'])" 2>/dev/null || echo "0")
cold=$(echo "$metrics_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['pipeline']['cold'])" 2>/dev/null || echo "0")

echo "  Tasks: done=${tasks_done} total=${tasks_total}"
echo "  Pipeline: accounts=${accounts} hot=${hot} warm=${warm} cold=${cold}"

# --- 2. Calculate health score components ---
echo "[2] Calculating health score..."

# Quality: task completion rate (done / total * 100)
if [[ "$tasks_total" -gt 0 ]]; then
    quality=$(( tasks_done * 100 / tasks_total ))
else
    quality=100
fi

# Efficiency: ratio of done to created (higher = more productive)
if [[ "$tasks_total" -gt 0 ]]; then
    efficiency=$(( tasks_done * 100 / tasks_total ))
else
    efficiency=0
fi

# Autonomy: 100 - override rate (read from AUTONOMY_LEVEL.md override log)
autonomy=100
autonomy_file="${AREA_ROOT}/state/AUTONOMY_LEVEL.md"
if [[ -f "$autonomy_file" ]]; then
    # Count only data rows in the Override Log table (after "## Override Log")
    # Skip header row, separator row, and placeholder "_none yet_" rows
    override_count=$(sed -n '/^## Override Log/,$ p' "$autonomy_file" 2>/dev/null \
        | grep "^|" | grep -v "^| Date" | grep -v "^|---" | grep -cv "_none yet_" 2>/dev/null || echo "0")
    if [[ $override_count -gt 0 ]]; then
        # Simple: each override reduces autonomy score by 10
        autonomy=$((100 - override_count * 10))
        [[ $autonomy -lt 0 ]] && autonomy=0
    fi
fi

# Evolution: experiments + learnings (simple heuristic)
evolution=50  # baseline
experiments_file="${AREA_ROOT}/shared/EXPERIMENTS.md"
learnings_file="${AREA_ROOT}/shared/LEARNINGS.md"
if [[ -f "$experiments_file" ]]; then
    completed_exp=$(grep -c "^### EXP-" "$experiments_file" 2>/dev/null || echo "0")
    evolution=$((50 + completed_exp * 10))
    [[ $evolution -gt 100 ]] && evolution=100
fi
if [[ -f "$learnings_file" ]]; then
    learnings_count=$(grep -c "^-" "$learnings_file" 2>/dev/null || echo "0")
    evolution=$((evolution + learnings_count * 2))
    [[ $evolution -gt 100 ]] && evolution=100
fi

health=$(( (quality + efficiency + autonomy + evolution) / 4 ))

echo "  Quality: ${quality} | Efficiency: ${efficiency} | Autonomy: ${autonomy} | Evolution: ${evolution}"
echo "  Health score: ${health}"

# --- 3. Update OBJECTIVES.md current values ---
echo "[3] Updating OBJECTIVES.md..."
if [[ -f "$OBJECTIVES" ]]; then
    today=$(date +%Y-%m-%d)
    sed -i '' "s/^updated: .*/updated: ${today}/" "$OBJECTIVES" 2>/dev/null || true
    echo "  Updated timestamp in OBJECTIVES.md"
fi

# --- 4. Append weekly snapshot (Mondays or --force) ---
day_of_week=$(date +%u)  # 1=Monday
if [[ "$day_of_week" == "1" || "$FORCE" == "--force" ]]; then
    echo "[4] Appending weekly snapshot to KPI_HISTORY.md..."
    if [[ -f "$KPI_HISTORY" ]]; then
        today=$(date +%Y-%m-%d)
        week_num=$(date +%V)

        cat >> "$KPI_HISTORY" << SNAPSHOT_EOF

### Week ${week_num} -- ${today}

| KPI | Value | Target | Delta | Trend |
|-----|-------|--------|-------|-------|
| Tasks completed | ${tasks_done} | - | - | - |
| Tasks in pipeline | ${tasks_total} | - | - | - |
| Pipeline accounts | ${accounts} | - | - | - |
| Hot leads | ${hot} | - | - | - |
| Warm leads | ${warm} | - | - | - |
| Cold leads | ${cold} | - | - | - |
| Health score | ${health} | - | - | - |

Notes: Auto-generated by measure-kpis.sh
SNAPSHOT_EOF

        echo "  Snapshot appended for Week ${week_num}"
    fi
else
    echo "[4] Skipping weekly snapshot (today is not Monday, use --force to override)"
fi

echo ""
echo "Done."
