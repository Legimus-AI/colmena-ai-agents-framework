#!/bin/bash
# AOS — Create a new Area Operating System
# Usage: ./create-area.sh <target-path> <area-name> <agent1> <agent2> ...
#
# Example: ./create-area.sh /path/to/vault/020_Agentes/Soporte soporte triager resolver escalator

set -euo pipefail

TARGET="${1:-}"
AREA_NAME="${2:-}"
shift 2 2>/dev/null || true
AGENTS=("$@")

if [[ -z "$TARGET" || -z "$AREA_NAME" || ${#AGENTS[@]} -eq 0 ]]; then
    echo "Usage: ./create-area.sh <target-path> <area-name> <agent1> <agent2> ..."
    echo ""
    echo "Example:"
    echo "  ./create-area.sh ./soporte soporte triager resolver escalator"
    echo ""
    echo "This creates an AOS skeleton at <target-path> with:"
    echo "  - Area CLAUDE.md and MANIFEST.md"
    echo "  - state/ (STATE.md, QUEUE.md, LOG.md)"
    echo "  - shared/ (empty, ready for area-specific knowledge)"
    echo "  - agents/orchestrator/ + agents/<each-agent>/"
    echo "  - tasks/ (inbox, doing, review, done)"
    echo "  - handoffs/"
    echo "  - rhythm/ (daily, weekly)"
    exit 1
fi

echo "Creating AOS area: ${AREA_NAME}"
echo "Target: ${TARGET}"
echo "Agents: orchestrator ${AGENTS[*]}"
echo "---"

# Create directory structure
mkdir -p "${TARGET}"/{state,shared,rhythm/{daily,weekly}}
mkdir -p "${TARGET}/tasks"/{inbox,doing,review,done,_templates}
mkdir -p "${TARGET}/handoffs/_templates"
mkdir -p "${TARGET}/agents/orchestrator"

for agent in "${AGENTS[@]}"; do
    mkdir -p "${TARGET}/agents/${agent}"
done

# .gitkeep empty dirs
for dir in "${TARGET}/tasks"/{doing,review,done} "${TARGET}/handoffs" "${TARGET}/rhythm/weekly"; do
    touch "${dir}/.gitkeep"
done

# Area CLAUDE.md
cat > "${TARGET}/CLAUDE.md" << 'AREA_EOF'
# Area Operating System — {{AREA_NAME}}

**OVERRIDE RULE:** These instructions take ABSOLUTE PRIORITY over any global CLAUDE.md.

## Area Rules (ALL agents MUST follow)

### 1. Minimum Context Principle
Each agent reads MAX 5 files on session start:
1. This file (CLAUDE.md)
2. Your own agents/<you>/CLAUDE.md
3. Your own agents/<you>/working-memory.md
4. state/STATE.md
5. Your assigned task file

### 2. Write Boundaries
See MANIFEST.md for per-agent write permissions.
NEVER write outside your boundaries.

### 3. Task Workflow
Tasks MOVE between folders: inbox → doing → review → done
Update status in YAML frontmatter when moving.

### 4. Session End Protocol (MANDATORY)
1. Update your working-memory.md
2. Append to your run-log.md
3. Append to state/LOG.md: [agent-name] summary
4. Move task files to correct status folder
5. Create handoff if another agent needs to continue

### 5. Anti-Loop Rule
If a task bounces review → doing 2+ times, ESCALATE to human.

### 6. Dates
ISO 8601: YYYY-MM-DDTHH:MM:SS-05:00
AREA_EOF
sed -i '' "s/{{AREA_NAME}}/${AREA_NAME}/" "${TARGET}/CLAUDE.md"

# STATE.md
cat > "${TARGET}/state/STATE.md" << 'EOF'
---
updated: null
sprint: "Week 1"
blockers: []
---

## Current Situation
Area just created. No prior context.

## Priorities
(to be defined by orchestrator on first session)
EOF

# QUEUE.md
cat > "${TARGET}/state/QUEUE.md" << 'EOF'
# Task Queue

## Active
(none yet)

## Pending
(none yet)
EOF

# LOG.md
cat > "${TARGET}/state/LOG.md" << EOF
# Activity Log

## $(date +%Y-%m-%d)
- [system] AOS area '${AREA_NAME}' created with agents: orchestrator ${AGENTS[*]}
EOF

# Orchestrator CLAUDE.md
cat > "${TARGET}/agents/orchestrator/CLAUDE.md" << 'EOF'
# Agent: Orchestrator

## Identity
You plan, assign, review, and consolidate. You do NOT do the work yourself — you DELEGATE.

## Session Protocol
1. Read area CLAUDE.md + your working-memory.md + STATE.md + QUEUE.md + LOG.md (last 10)
2. Review tasks in tasks/review/
3. Create/assign new tasks in tasks/inbox/
4. Consolidate: update STATE.md, LOG.md, rhythm/
5. End: update working-memory.md + run-log.md

## Boundaries
WRITE: state/, shared/, tasks/, rhythm/, handoffs/
READ: everything
NEVER: do the specialist work yourself
EOF

cat > "${TARGET}/agents/orchestrator/working-memory.md" << 'EOF'
---
agent: orchestrator
last_session: null
status: idle
---
## Current State
First session. No prior context.
EOF

echo "# Run Log — Orchestrator" > "${TARGET}/agents/orchestrator/run-log.md"

# Sub-agent templates
for agent in "${AGENTS[@]}"; do
    cat > "${TARGET}/agents/${agent}/CLAUDE.md" << AGENT_EOF
# Agent: ${agent}

## Identity
You are the '${agent}' specialist. Follow your tasks, report results, stay in your lane.

## Session Protocol
1. Read area CLAUDE.md + your working-memory.md + STATE.md
2. Check tasks/inbox/ and tasks/doing/ for tasks with owner: ${agent}
3. Claim task: move to doing/ IMMEDIATELY before starting work
4. Execute task, write results
5. Move to tasks/review/, create handoff if needed
6. End: update working-memory.md + run-log.md + LOG.md

## Boundaries
WRITE: accounts/, agents/${agent}/, tasks/ (move only), handoffs/
READ: state/, shared/, assigned tasks
NEVER: modify state/ or shared/ directly
AGENT_EOF

    cat > "${TARGET}/agents/${agent}/working-memory.md" << AGENT_EOF
---
agent: ${agent}
last_session: null
status: idle
---
## Current State
First session. No prior context.
AGENT_EOF

    echo "# Run Log — ${agent}" > "${TARGET}/agents/${agent}/run-log.md"
done

# Task template
cat > "${TARGET}/tasks/_templates/task.md" << 'EOF'
---
id: TASK-XXX
title: ""
owner: agent-name
reviewer: orchestrator
priority: p0|p1|p2|p3
status: inbox
created: YYYY-MM-DD
due: YYYY-MM-DD
done_when:
  - criterion 1
---
## Objective
## Context
## Results
## Review Notes
EOF

# Handoff template
cat > "${TARGET}/handoffs/_templates/handoff.md" << 'EOF'
---
id: HO-XXX
from: agent
to: agent
task: TASK-XXX
status: pending
created: YYYY-MM-DDTHH:MM:SS-05:00
---
## What Was Done
## What's Needed Next
## Exact Next Action
EOF

# MANIFEST.md placeholder
cat > "${TARGET}/MANIFEST.md" << MANIFEST_EOF
# Squad Manifest — ${AREA_NAME}

## Orchestrator
- Mission: Plan, assign, review, consolidate
- Writes to: state/, shared/, tasks/, rhythm/, handoffs/
- Reads: everything
MANIFEST_EOF

for agent in "${AGENTS[@]}"; do
    cat >> "${TARGET}/MANIFEST.md" << MANIFEST_EOF

## ${agent}
- Mission: (define specific mission)
- Writes to: accounts/, agents/${agent}/, tasks/ (move only), handoffs/
- Reads: state/, shared/, assigned tasks
- Tools: (define specific tools)
MANIFEST_EOF
done

# Copy run.sh from this skeleton
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "${SCRIPT_DIR}/run.sh" ]]; then
    cp "${SCRIPT_DIR}/run.sh" "${TARGET}/run.sh"
    chmod +x "${TARGET}/run.sh"
fi

echo "---"
echo "AOS area '${AREA_NAME}' created at: ${TARGET}"
echo ""
echo "Next steps:"
echo "  1. Edit MANIFEST.md — define missions and tools per agent"
echo "  2. Edit agents/<name>/CLAUDE.md — write specific instructions"
echo "  3. Populate shared/ with area-specific knowledge"
echo "  4. Create initial tasks in tasks/inbox/"
echo "  5. Run: cd ${TARGET} && ./run.sh orchestrator"
