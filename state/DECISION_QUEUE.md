# CEO Decision Queue

> Items that require the CEO's input, judgment, or approval.
> Agents add items here. CEO resolves them.

## Urgency Levels

- :red_circle: **Now** — Blocking work. Needs decision within hours.
- :large_orange_circle: **Today** — Important but not blocking. Decide by end of day.
- :green_circle: **This week** — Strategic. Can wait for weekly review.

## Pending

<!-- Add new items at the top. Format:

### [URGENCY] Title
- **Context:** Why this decision is needed
- **Options:** A) ... B) ... C) ...
- **Recommendation:** What the orchestrator suggests and why
- **Deadline:** YYYY-MM-DD (when this becomes blocking)
- **Added by:** [agent-name], YYYY-MM-DD

-->

_No pending decisions._

## Resolved

<!-- Move items here after CEO decides. Add:
- **Decision:** What the CEO chose
- **Resolved:** YYYY-MM-DD

### [URGENCY] Title
- **Context:** ...
- **Decision:** [CEO's choice]
- **Resolved:** YYYY-MM-DD

-->

_No resolved decisions yet._

## Instructions for Agents

1. **Any agent** can add items to the Pending section.
2. Use the format above. Always include Context, Options, and Recommendation.
3. Set urgency honestly — not everything is :red_circle:.
4. The orchestrator checks the Resolved section on every session for CEO responses.
5. After processing a resolved decision, the orchestrator moves it to the bottom of Resolved.
6. If a pending item's deadline passes without resolution, the orchestrator escalates (re-notify CEO).
