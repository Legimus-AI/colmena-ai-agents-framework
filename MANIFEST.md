# Squad Manifest — Ventas

## Orchestrator
- **Mission:** Prioritize, assign, review, consolidate. The "manager" of the sales area.
- **Writes to:** state/, shared/, tasks/, rhythm/, handoffs/
  - `state/OBJECTIVES.md` — update current values (NOT targets)
  - `state/KPI_HISTORY.md` — via measure-kpis.sh (append-only)
  - `state/DECISION_QUEUE.md` — add items + process resolved
  - `state/AUTONOMY_LEVEL.md` — append to override log only (level is CEO-write)
  - `shared/EXPERIMENTS.md` — propose, update status, record results
  - Note: `state/HITL_MATRIX.md` is **CEO-only write** (agents read it)
  - Note: `state/AUTONOMY_LEVEL.md` level/promotion fields are **CEO-only write**
- **Reads:** everything
- **Tools:** web search, file read/write
- **MCP servers:** none (no browser needed)
- **Frequency:** 2x/day (morning planning + afternoon review)
- **Escalation:** If blocked, write to state/LOG.md and notify Victor

## Researcher
- **Mission:** Investigate prospects — company data, decision makers, contacts, scoring
- **Writes to:** accounts/, agents/researcher/, tasks/ (move only), handoffs/
- **Reads:** state/STATE.md, shared/ICP.md, shared/PLAYBOOKS.md, assigned tasks
- **Tools:** web search, Chrome DevTools MCP, Playwright MCP
- **MCP servers:** chrome-devtools, playwright
- **Frequency:** 1x/day or on-demand (when tasks exist in inbox)
- **Output:** Prospect fichas in accounts/<slug>/overview.md

## Writer
- **Mission:** Convert research into personalized outreach sequences and proposals
- **Writes to:** accounts/*/artifacts/, agents/writer/, tasks/ (move only), handoffs/
- **Reads:** accounts/, shared/, handoffs/ from researcher
- **Tools:** file read/write (vault only)
- **MCP servers:** none
- **Frequency:** 1x/day or on-demand
- **Output:** Outreach sequences in accounts/<slug>/artifacts/

## Closer
- **Mission:** Prepare demos, handle objections, manage post-demo follow-up, close deals
- **Writes to:** accounts/, agents/closer/, tasks/ (move only), shared/OBJECTIONS.md, handoffs/
- **Reads:** everything
- **Tools:** web search, Telegram (notifications)
- **MCP servers:** chrome-devtools (for demo prep)
- **Frequency:** On-demand (pre-demo, post-demo, objection handling)
- **Output:** Demo briefs, objection responses, closing proposals
