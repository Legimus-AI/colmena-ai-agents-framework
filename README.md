# Colmena — AI Agent Team Framework

A markdown-based framework for running autonomous AI agent teams that outperform organized human teams.

Built for [Claude Code](https://claude.ai/code). No databases, no vector stores, no infra — just markdown files + bash scripts.

## How It Works

```
                    ┌─────────────────┐
                    │  Victor (Human)  │
                    │                  │
                    │  HUMAN_INPUT.md  │◄── writes directives
                    │  tasks/approval/ │◄── approves critical actions
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  ORCHESTRATOR   │
                    │                 │
                    │  Plans, assigns │
                    │  reviews, ships │
                    └──┬──────┬───┬──┘
                       │      │   │
              ┌────────▼──┐ ┌─▼───▼──────┐ ┌──────────┐
              │ RESEARCHER │ │   WRITER   │ │  CLOSER  │
              │            │ │            │ │          │
              │ Prospects  │ │ Outreach   │ │ Demos    │
              │ Research   │ │ Sequences  │ │ Closing  │
              └─────┬──────┘ └─────┬──────┘ └────┬─────┘
                    │              │              │
                    ▼              ▼              ▼
              ┌──────────────────────────────────────┐
              │         SHARED FILE SYSTEM            │
              │                                       │
              │  state/      ← control plane          │
              │  shared/     ← team knowledge         │
              │  tasks/      ← file-as-workflow       │
              │  accounts/   ← CRM data               │
              │  handoffs/   ← agent-to-agent comms   │
              └──────────────────────────────────────┘
```

### The Agent Cycle

```
1. ORCHESTRATOR reads state → creates tasks in inbox/
                                          │
2. AGENTS claim tasks ──────► inbox/ ──► doing/ ──► review/ ──► done/
   (move-task.sh)                                      │
                                                       ▼
3. ORCHESTRATOR reviews ◄─── quality rubric (5 criteria)
                                                       │
4. If requires_approval ──────────────────────► approval/
                                                       │
5. VICTOR approves ──────────────────────────► done/ ◄─┘
```

### Cross-Area Communication

```
  VENTAS AREA                        DEV AREA
  ┌──────────┐                      ┌──────────┐
  │  Closer   │──► cross-area/ ──►  │ Orchestr │──► creates Jira card
  │ finds bug │    outbox/          │ reads it │
  └──────────┘                      └──────────┘
```

## Quick Start

```bash
# Run full cycle (orchestrator → researcher → writer → closer → orchestrator review)
./run-cycle.sh

# Run a single agent
./run.sh orchestrator
./run.sh researcher

# Check vault health
./scripts/validate.sh

# View metrics
./scripts/rollup-metrics.sh

# Dry run (preview prompt)
./run.sh orchestrator --dry-run
```

## File Structure

```
CLAUDE.md              ← Area rules (every agent reads this FIRST)
MANIFEST.md            ← Roles, tools, permissions per agent
run.sh                 ← Run one agent (with output capture + validation)
run-cycle.sh           ← Run full agent cycle with inter-step validation
create-area.sh         ← Generate a new area from scratch
mcp-config.json        ← MCP server config for browser agents
.next-id               ← Atomic task ID counter

state/                 ← Control plane (orchestrator writes)
  STATE.md             ← Status, metrics, blockers (YAML frontmatter)
  QUEUE.md             ← Prioritized task backlog
  LOG.md               ← Activity log (all agents append-only)
  HUMAN_INPUT.md       ← Victor's directives to the team
  OBJECTIVES.md        ← North Star + Key Results (Jarvis OS)
  KPI_HISTORY.md       ← Weekly KPI snapshots (append-only)
  DECISION_QUEUE.md    ← CEO decision queue with urgency levels
  AUTONOMY_LEVEL.md    ← Current autonomy level + override log
  HITL_MATRIX.md       ← Risk x Reversibility decision matrix

shared/                ← Team knowledge (orchestrator curates)
  PIPELINE.md          ← Sales pipeline (auto-synced from accounts/)
  ICP.md               ← Ideal customer profile
  PLAYBOOKS.md         ← Approved playbooks
  OBJECTIONS.md        ← Objection database
  LEARNINGS.md         ← Shared lessons learned
  EXPERIMENTS.md       ← Hypothesis testing tracker (Jarvis OS)

agents/                ← One folder per agent
  <name>/CLAUDE.md            ← Identity + instructions
  <name>/working-memory.md    ← Current state (max 50 lines)
  <name>/run-log.md           ← Session history (append-only)

tasks/                 ← File-as-workflow (files MOVE between folders)
  inbox/               ← New (orchestrator creates)
  doing/               ← Agent working on it
  review/              ← Done, awaiting orchestrator review
  approval/            ← Needs HUMAN approval (critical actions)
  done/                ← Completed and approved
  archive/             ← Monthly archives

handoffs/              ← Inter-agent communication
  processed/           ← Completed handoffs

accounts/              ← CRM-like prospect data
  <slug>/overview.md      ← Prospect ficha
  <slug>/activity.md      ← Interaction history
  <slug>/artifacts/       ← Proposals, outreach, research

cross-area/            ← Communication with other areas
  inbox/               ← Incoming from other areas
  outbox/              ← Outgoing to other areas

rhythm/                ← Operating cadence
  daily/               ← Daily logs
  weekly/              ← Weekly summaries
  templates/           ← Report templates (Jarvis OS)
    weekly-report.md   ← CEO-facing area report template
    daily-digest.md    ← Telegram notification template

scripts/               ← Automation
  move-task.sh         ← Atomic task mover (agents MUST use this)
  next-id.sh           ← Atomic ID generator (orchestrator uses this)
  validate.sh          ← State consistency checker + auto-fixer
  rollup-metrics.sh    ← Auto-calculate metrics from filesystem
  sync-pipeline.sh     ← Regenerate PIPELINE.md from accounts/
  maintenance.sh       ← Archive old tasks, prune memory, rotate logs

logs/                  ← Agent session output (auto-captured by run.sh)
```

## Key Principles

1. **Source of truth is unique** — each data point lives in ONE file
2. **Minimum context** — agents read max 5 files on session start
3. **File-as-workflow** — tasks move between folders via `move-task.sh`
4. **Write boundaries** — each agent can only write to specific directories
5. **Human approval gate** — critical actions (emails, payments) need Victor's OK
6. **Auto-validation** — every run ends with `validate.sh --fix`
7. **Crash recovery** — stale locks auto-detected, stuck tasks auto-recovered
8. **Anti-loop** — tasks that bounce 2+ times escalate to human

## Governance --- Jarvis OS

The optional governance layer adds objectives, autonomy levels, decision escalation, anomaly detection, and structured reporting on top of the core file-as-workflow engine.

### Objective-Driven Behavior

Each area has a **North Star** metric and **Key Results** in `state/OBJECTIVES.md`. The orchestrator checks these every session:
- KRs on track (>=80%) → continue current plan
- KRs off track (<80%) → create corrective tasks autonomously
- KRs critical (<50%) → escalate to CEO via `state/DECISION_QUEUE.md`
- Empty inbox + below target → orchestrator generates work proactively

### Autonomy Ladder (4 Levels)

Areas earn trust over time, reducing the need for human approval:

| Level | Name | What's autonomous |
|-------|------|-------------------|
| 1 | Aprendiz | Internal ops only. All external actions need approval |
| 2 | Operador | Routine external actions (matching playbook) are autonomous |
| 3 | Manager | Fully autonomous. Weekly report only |
| 4 | Director | Can propose strategy changes and budget allocation |

Promotion is automatic based on low override rates over consecutive weeks. See `state/AUTONOMY_LEVEL.md`.

### HITL Matrix

`state/HITL_MATRIX.md` defines a **Risk x Reversibility** matrix. For every action category, it specifies whether the action is autonomous, notify-only, or requires CEO approval — per autonomy level. Agents check this before any non-trivial action.

### Decision Queue

When agents face decisions beyond their autonomy level, they add structured items to `state/DECISION_QUEUE.md` with urgency (red/yellow/green), context, options, and a recommendation. The CEO resolves items there.

### Health Monitoring

Two scripts run automatically:
- **`check-anomalies.sh`** — Detects stale approvals, stalled tasks, off-track objectives, and validation errors. Sends Telegram alerts for critical items.
- **`health-check.sh`** — Dead Man's Snitch. Alerts if no agent activity for N hours, stale lockfiles, or low disk space.

### Learning Loop

- **Experiments** (`shared/EXPERIMENTS.md`) — Hypotheses are tested, measured, and documented. Failed experiments are learning, not waste.
- **Playbook proposals** — When the area accumulates 3+ learnings in a week, the orchestrator proposes a playbook change to the CEO.

### KPI Tracking

- **`measure-kpis.sh`** — Runs metrics rollup, calculates health scores, updates OBJECTIVES.md, and appends weekly snapshots to `state/KPI_HISTORY.md`.
- Weekly snapshots enable trend analysis (week-over-week comparison).

### Area Report

The orchestrator generates a weekly report using `rhythm/templates/weekly-report.md` — designed for the CEO to read in under 5 minutes. Includes: North Star status, KRs, decision queue, health score, alerts, and learnings.

## How the CEO Works with Areas

The CEO **never opens files**. All interaction happens through the notification channel (Telegram, Slack, etc.). The markdown files are the area's internal records.

### CEO's daily routine (5 minutes)

1. **8am** — Receive 3-line daily status via notification. Glance. Done.
2. **When notified** — Area sends approval request with full draft + context. Reply: "approved", "change X", or "no". Area executes.
3. **When escalated** — Area sends decision with options: "A) ... B) ... C) ... I recommend B." Reply with your choice. Area resolves.
4. **Silence** — Means everything is on track. No news is good news.

### What the CEO does NOT do

- Open files or SSH into servers
- Fill out `HUMAN_INPUT.md` (the area writes your directives there as an internal log)
- Check `tasks/approval/` manually (the area sends drafts via notification)
- Browse `DECISION_QUEUE.md` (the area sends decisions via notification, logs your response there)

### What the CEO does

| Action | How |
|--------|-----|
| Give directives | Tell the orchestrator via notification channel. It records and executes. |
| Approve outputs | Area sends the draft. CEO replies approve/reject/change. |
| Make decisions | Area sends options + recommendation. CEO picks. |
| Change priorities | Tell the orchestrator. It re-prioritizes everything. |
| Monitor | Read the daily notification + weekly AREA Report summary. |

### How trust grows (Autonomy Ladder)

At **Level 1**, the area asks you about everything external. Over weeks, if your corrections are rare (<20% override rate), the area automatically earns **Level 2** and handles routine tasks alone. By **Level 3**, you only see the weekly report. By **Level 4**, the area proposes strategy changes to you.

## Creating a New Area

```bash
./create-area.sh /path/to/new/area area-name agent1 agent2 agent3
# Example:
./create-area.sh ../Soporte soporte triager resolver escalator
```

Then customize: MANIFEST.md, agent CLAUDE.md files, shared/ knowledge.

## Scripts Reference

| Script | Purpose | Who uses it |
|--------|---------|-------------|
| `run.sh <agent>` | Run one agent session | Human or cron |
| `run-cycle.sh` | Full cycle with validation | Human or cron |
| `scripts/move-task.sh` | Move task between folders | Agents (mandatory) |
| `scripts/next-id.sh` | Get next task ID | Orchestrator |
| `scripts/validate.sh` | Check + fix consistency | run.sh (auto), human |
| `scripts/rollup-metrics.sh` | Calculate metrics | Orchestrator, human |
| `scripts/sync-pipeline.sh` | Sync PIPELINE.md from accounts/ | Orchestrator |
| `scripts/maintenance.sh` | Archive, prune, rotate | Cron (weekly) |
| `scripts/check-anomalies.sh` | Detect stale tasks, off-track KRs | run.sh (auto), cron |
| `scripts/health-check.sh` | Dead Man's Snitch + infra checks | Cron (hourly) |
| `scripts/measure-kpis.sh` | Calculate KPIs, update objectives | run-cycle.sh, orchestrator |
| `scripts/generate-daily-status.sh` | 3-line daily summary + notification | Cron (daily 8am) |
| `scripts/generate-weekly-report.sh` | CEO-facing weekly AREA Report | Orchestrator, cron (weekly) |

## Why This Beats Human Teams

| Dimension | Humans | Colmena |
|-----------|--------|-----|
| Memory | Forgets between meetings | Perfect persistence via files |
| Handoffs | "I'll Slack you" (context lost) | Structured file with full context |
| Availability | 8h/day, 5 days/week | 24/7 via cron |
| Parallelism | 1 person = 1 task | N agents on N accounts |
| Consistency | Varies by person/mood | Same protocol every time |
| Onboarding | Weeks for new hire | Read CLAUDE.md = instant |
| Meetings | 30min/day standups | Zero — the vault IS the standup |
| Cost | $3-8K/month per person | ~$50-200/month in API calls |
| Audit trail | "Who said what?" = lost | Everything in files with timestamps |
| Quality control | Depends on manager | Automated validation + rubric |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Agent already running" | Stale lock auto-cleaned (dead PID detection) |
| Duplicate tasks | `validate.sh --fix` auto-deduplicates (keeps most advanced status) |
| Task stuck in doing/ | Orchestrator detects on next run → moves back to inbox |
| Working memory bloated | `maintenance.sh` trims to 50 lines |
| PIPELINE.md wrong | `sync-pipeline.sh` regenerates from accounts/ |
| Agent ignores boundaries | `--allowedTools` restricts tools at CLI level |
| Need to debug agent | Check `logs/<agent>-<timestamp>.log` |
