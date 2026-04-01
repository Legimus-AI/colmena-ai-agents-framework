# Human-in-the-Loop Decision Matrix

> Determines when an action is autonomous, notify-only, or requires CEO approval.
> Cross-reference with `AUTONOMY_LEVEL.md` for current level overrides.

## Universal Rule

An action is **autonomous** (no approval needed) ONLY if ALL of these are true:

1. **Reversible** — Can be undone without lasting damage
2. **Low cost** — No financial commitment or < $10
3. **Within playbook** — Matches an existing approved pattern
4. **No legal/brand impact** — Does not represent the company publicly
5. **High confidence** — Agent is >90% sure this is correct

If ANY condition fails → escalate per the matrix below.

## Risk x Reversibility Matrix

```
                    REVERSIBLE              IRREVERSIBLE
                ┌───────────────────┬───────────────────┐
   LOW RISK     │   AUTONOMOUS      │   NOTIFY          │
                │   (just do it)    │   (do + inform)   │
                ├───────────────────┼───────────────────┤
   HIGH RISK    │   NOTIFY          │   HITL             │
                │   (do + inform)   │   (approval first) │
                └───────────────────┴───────────────────┘
```

## Action Categories

### Internal Operations
| Action | Risk | Reversible? | Default | L1 | L2 | L3 | L4 |
|--------|------|-------------|---------|----|----|----|----|
| Create/move tasks | Low | Yes | Auto | Auto | Auto | Auto | Auto |
| Update state files | Low | Yes | Auto | Auto | Auto | Auto | Auto |
| Update playbooks | Med | Yes | Notify | HITL | Notify | Auto | Auto |
| Archive old data | Low | Yes | Auto | Auto | Auto | Auto | Auto |
| Delete files | Med | No | HITL | HITL | HITL | Notify | Auto |

### External Communications
| Action | Risk | Reversible? | Default | L1 | L2 | L3 | L4 |
|--------|------|-------------|---------|----|----|----|----|
| Send email to prospect | High | No | HITL | HITL | HITL | Auto | Auto |
| Send message (WhatsApp, LinkedIn) | High | No | HITL | HITL | HITL | Auto | Auto |
| Follow-up (matching playbook) | Med | No | Notify | HITL | Notify | Auto | Auto |
| Publish social media | High | No | HITL | HITL | HITL | HITL | Notify |
| Reply to inbound inquiry | Med | No | Notify | HITL | Notify | Auto | Auto |

### Financial
| Action | Risk | Reversible? | Default | L1 | L2 | L3 | L4 |
|--------|------|-------------|---------|----|----|----|----|
| Purchase < $10 | Low | No | Notify | HITL | Notify | Auto | Auto |
| Purchase $10-100 | Med | No | HITL | HITL | HITL | Notify | Auto |
| Purchase > $100 | High | No | HITL | HITL | HITL | HITL | HITL |
| Offer discount/pricing | High | No | HITL | HITL | HITL | HITL | Notify |

### Data Management
| Action | Risk | Reversible? | Default | L1 | L2 | L3 | L4 |
|--------|------|-------------|---------|----|----|----|----|
| Create account/prospect files | Low | Yes | Auto | Auto | Auto | Auto | Auto |
| Update account data | Low | Yes | Auto | Auto | Auto | Auto | Auto |
| Merge/deduplicate accounts | Med | No | Notify | HITL | Notify | Auto | Auto |
| Export data externally | High | No | HITL | HITL | HITL | HITL | Notify |

## Legend

- **Auto** = Autonomous, just do it
- **Notify** = Do it, then inform CEO (append to LOG.md + daily digest)
- **HITL** = Human-in-the-loop. Move task to `tasks/approval/`. Do NOT execute until CEO approves.

## Instructions for Agents

1. Before any action, identify its category and check the column for the current autonomy level.
2. If the matrix says **HITL**: prepare all artifacts, move task to `approval/`, stop.
3. If the matrix says **Notify**: execute the action, then append a line to `state/LOG.md`.
4. If the matrix says **Auto**: just do it.
5. When in doubt, escalate. It's better to ask than to make an irreversible mistake.
6. This file is **CEO-only write**. Agents read it but never modify it.
