# S-005 - External Thesis Playtest

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-005
**Status:** planned
**Priority:** 3
**Owner:** Kayden
**Updated:** 2026-07-13
**Catalog description:** Test the v2 thesis slice with at least two new players and convert observed confusion and fun into evidence-backed follow-up specs.
**Blockers:** S-004
**Latest event:** Capability migrated from legacy T-095; no external sessions are claimed complete.
**Next gate:** Complete S-004 and prepare a neutral first-session script.

## Outcome

Players who did not design the game reveal whether the shared verbs are
discoverable, the encounter transition is understandable, and the thesis loop
is fun without coaching.

## Why It Matters

Steam-first product decisions require external evidence before the roster or
world becomes expensive to rework.

## Current Verified State

Internal owner and agent proof exists for individual prototypes. No external
tester evidence exists for the integrated v2 thesis slice.

## Desired Behavior

- At least two new players attempt the same first-session route.
- Notes distinguish observation from interpretation.
- The session captures confusion, discovery, fun/not-fun, and completion.
- Findings become explicit follow-up or superseding specs rather than an
  untracked backlog dump.

## Decisions And Contracts

- Testers receive controls and accessibility help, not puzzle or verb answers.
- Preserve negative evidence; do not rewrite the result into a success claim.

## Non-Goals

- Marketing research, broad telemetry, public release, or statistical claims
  from a two-person qualitative test.

## Dependencies And Blockers

- `S-004` complete and owner-accepted.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Prepare the build, neutral script, consent boundary, and note template. | ready | S-004 | pending |
| TK-002 | Run at least two external first sessions. | ready | TK-001 | pending |
| TK-003 | Synthesize findings and create linked follow-up specs. | ready | TK-002 | pending |

## Acceptance Criteria

- [ ] At least two external players complete or stop the first session.
- [ ] Notes capture discovery, confusion, and fun without coaching.
- [ ] Findings separate observed behavior from product inference.
- [ ] Every actionable result is linked to a follow-up, superseding spec, or an
  explicit no-change decision.

## Testing Seams

- Repeatable build and first-session route.
- Consistent note template across testers.
- Trace from each recommendation back to observed session evidence.

## Verification Procedure

```bash
# Run the release candidate verification suite defined by S-004 before sessions.
# Record the exact tested commit and build artifact in this spec.
```

## Documentation Impact

- Update the spec evidence, resulting Blueprint decisions, and linked follow-up
  specs. Do not copy live follow-up state into the Taskboard manually.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-13 | spec | Migrated from legacy T-095 | scope reconciled with Steam-first D-032 | v2.3 spec created | S-004 and all playtest slices |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- A two-person qualitative test guides direction but does not establish market
  fit or population-level usability.

## Supersession

- Supersedes: none
- Superseded by: none

