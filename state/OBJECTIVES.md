---
north_star:
  metric: "[Primary KPI — e.g., Monthly Recurring Revenue, Active Users, Deals Closed]"
  current: 0
  target: 10
  unit: "[unit]"
  trend: "→"  # ↑ improving, → flat, ↓ declining
updated: 2026-01-01
---

# Area Objectives

## North Star

> **[Metric Name]:** 0 / 10 [unit] (→ flat)

The North Star is the ONE metric that, if it moves, everything else follows.
All Key Results below exist to drive this metric.

## Key Results (this quarter)

| # | Key Result | Metric | Current | Target | Status |
|---|-----------|--------|---------|--------|--------|
| KR1 | [First key result description] | [metric] | 0 | [target] | :white_circle: Not started |
| KR2 | [Second key result description] | [metric] | 0 | [target] | :white_circle: Not started |
| KR3 | [Third key result description] | [metric] | 0 | [target] | :white_circle: Not started |

**Status legend:**
- :red_circle: Critical (<50% of target)
- :large_orange_circle: Off track (50-79%)
- :green_circle: On track (>=80%)
- :white_circle: Not started

## Cadence

- **Daily:** Orchestrator checks KRs on every session. If a KR is off-track, create corrective tasks immediately.
- **Weekly:** `measure-kpis.sh` appends a snapshot to `KPI_HISTORY.md`. Orchestrator reviews trends.
- **Monthly:** CEO reviews targets. Adjusts North Star or KRs if strategy changes.

## Instructions for Orchestrator

1. **Read this file at the START of every session** (before planning tasks).
2. Compare each KR's `current` vs `target`. Calculate completion = current / target * 100.
3. If any KR is :red_circle: (<50%), add a :red_circle: item to `DECISION_QUEUE.md` and create at least 1 corrective task.
4. If any KR is :large_orange_circle: (50-79%), create tasks to address the gap — do NOT wait for CEO input.
5. If all KRs are :green_circle: (>=80%), focus on acceleration or propose new stretch targets.
6. **Update `current` values** whenever you have new data (from task completions, metrics rollup, etc.).
7. **Update `trend`** based on week-over-week direction from `KPI_HISTORY.md`.
8. Never change `target` — only the CEO can modify targets.
