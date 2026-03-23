# AOS — Area Operating System

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

shared/                ← Team knowledge (orchestrator curates)
  PIPELINE.md          ← Sales pipeline (auto-synced from accounts/)
  ICP.md               ← Ideal customer profile
  PLAYBOOKS.md         ← Approved playbooks
  OBJECTIONS.md        ← Objection database
  LEARNINGS.md         ← Shared lessons learned

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

## How Victor Interacts

| Action | How |
|--------|-----|
| Give directives | Edit `state/HUMAN_INPUT.md` → add under `## Pending` |
| Approve outreach | Check `tasks/approval/` → move to `tasks/done/` if OK |
| Give feedback | Edit task file → add to `## Review Notes` |
| Override priorities | Edit `state/STATE.md` or `state/QUEUE.md` |
| Monitor | `./scripts/rollup-metrics.sh` or check `logs/` |
| Get notified | Telegram notification auto-sent when tasks hit approval/ |

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

## Why This Beats Human Teams

| Dimension | Humans | AOS |
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
