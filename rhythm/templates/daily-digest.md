# Daily Digest Template

> 3-line Telegram notification sent by `check-anomalies.sh` or orchestrator.
> Designed for quick scanning on mobile.

## Format

```
[Area Name]: [tasks_done] done, [tasks_doing] active | [approval_count] awaiting approval
North Star: [current]/[target] ([trend])
[alerts_count] alerts | [urgent_decisions] urgent decisions
```

## Example

```
Sales: 2 done, 3 active | 1 awaiting approval
North Star: 3/10 deals (up)
0 alerts | 0 urgent decisions
```

## When to Send

- At the end of each `run-cycle.sh` execution
- When `check-anomalies.sh` detects a problem
- The orchestrator may trigger this manually during session end

## Variables

| Placeholder | Source |
|-------------|--------|
| `[Area Name]` | CLAUDE.md area identity |
| `[tasks_done]` | `rollup-metrics.sh --json` → tasks.done |
| `[tasks_doing]` | `rollup-metrics.sh --json` → tasks.doing |
| `[approval_count]` | count of files in tasks/approval/ |
| `[current]` | OBJECTIVES.md → north_star.current |
| `[target]` | OBJECTIVES.md → north_star.target |
| `[trend]` | OBJECTIVES.md → north_star.trend |
| `[alerts_count]` | from check-anomalies.sh |
| `[urgent_decisions]` | count of red items in DECISION_QUEUE.md |
