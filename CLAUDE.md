# Area Operating System — Ventas (TEST)

> This is the area-level CLAUDE.md. Every agent in this area reads this file first.

## Area Identity

- **Area:** Ventas / Sales
- **Company:** Legimus AI (SaaS B2B — AI-powered sales assistant for e-commerce)
- **Objective:** Generate qualified pipeline and close founding partners
- **Market:** Peru (primary), Chile (secondary)

## Area Rules (ALL agents MUST follow)

### 1. Source of Truth

Each piece of data lives in ONE file only. Never duplicate.

| Data | Lives in | Updated by |
|------|----------|------------|
| Pipeline state | shared/PIPELINE.md | orchestrator |
| Area status + metrics | state/STATE.md | orchestrator |
| Task queue | state/QUEUE.md | orchestrator |
| Activity log | state/LOG.md | all (append-only) |
| Prospect data | accounts/<slug>/overview.md | researcher |
| Interaction history | accounts/<slug>/activity.md | whoever interacts |
| Outreach drafts | accounts/<slug>/artifacts/ | writer |
| Objections DB | shared/OBJECTIONS.md | closer |
| Learnings | shared/LEARNINGS.md | orchestrator (consolidates) |

### 2. Minimum Context Principle

Each agent reads MAX 5 files on session start:
1. This file (CLAUDE.md) — area rules
2. Your own `agents/<you>/CLAUDE.md` — your role
3. Your own `agents/<you>/working-memory.md` — your state
4. `state/STATE.md` — area context
5. Your assigned task file (1 file from tasks/)

Only read additional files if the task explicitly requires it.

### 3. Write Boundaries

| Agent | Can write to |
|-------|-------------|
| orchestrator | state/, shared/, tasks/, rhythm/, handoffs/ |
| researcher | accounts/, agents/researcher/, tasks/ (move only), handoffs/ |
| writer | accounts/*/artifacts/, agents/writer/, tasks/ (move only), handoffs/ |
| closer | accounts/, agents/closer/, tasks/ (move only), shared/OBJECTIONS.md, handoffs/ |

**NEVER write outside your boundaries.** If you need something updated outside your scope, create a handoff.

### 4. Task Workflow

Tasks are files that MOVE between folders:
```
tasks/inbox/    → New task created by orchestrator
tasks/doing/    → Agent picks it up and moves it here
tasks/review/   → Agent finishes and moves it here
tasks/done/     → Orchestrator approves and moves it here
```

When moving a task, also update the `status` field in the YAML frontmatter.

### 5. Session Protocol

**On session start:**
1. Read your 5 files (minimum context)
2. Check tasks/inbox/ and tasks/doing/ for tasks assigned to you
3. If no tasks → report to orchestrator via state/LOG.md and end session

**On session end (MANDATORY):**
1. Update your working-memory.md with current state
2. Append to your run-log.md: date, what you did, what's next
3. Append to state/LOG.md: `[agent-name] <summary of actions>`
4. Move task files to correct status folder
5. Create handoff in handoffs/ if another agent needs to continue

### 6. Handoff Protocol

When your work needs another agent to continue:
1. Create `handoffs/HO-XXX-from-to.md` using the template
2. Include: what's done, what's needed, reference files, risks
3. The receiving agent will find it on their next session

### 7. Anti-Loop Rule

If a task bounces between review → doing more than 2 times, STOP and write:
```
## ESCALATION
This task has been reviewed 2+ times without passing. Escalating to Victor.
Reason: [why it keeps failing]
```

### 8. Date Convention

All dates in ISO 8601: `2026-03-23T14:30:00-05:00` (Lima timezone, UTC-5).

## Invocation

Each agent is invoked as a separate Claude Code session:
```bash
# From the area root directory
cd /tmp/aos-test-ventas
claude --print "You are the orchestrator agent. Read your CLAUDE.md at agents/orchestrator/CLAUDE.md and execute your session protocol."
```

See `run.sh` for the full invocation script.
