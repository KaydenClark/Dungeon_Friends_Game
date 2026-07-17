# S-013 - Finite Progression And Recruitment

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-013
**Status:** planned
**Priority:** 2
**Owner:** Kayden
**Updated:** 2026-07-17
**Catalog description:** Define and implement finite no-grind progression, defeat/revive rules, one real recruit, equipment/economy seams, and the character surface.
**Blockers:** S-003, S-012
**Latest event:** Live v1 XP/items/defeat state and legacy T-056/T-070/T-071/T-076 evidence were reconciled; the finite-XP fork is unresolved.
**Next gate:** Kayden resolves blocked TK-001 before an Engineer changes progression behavior; Kayden later owns the blocked TK-006 balance verdict.

## Outcome

Finite authored encounters, quests, discoveries, recruitment, equipment, and
world resolution produce understandable progression without grinding, while
defeat and downed allies remain recoverable and fair.

## Why It Matters

D-028 removes repeatable enemy XP. The existing 25% XP penalty, deterministic
v1 loot, downed-companion behavior, and future shops/equipment cannot be carried
forward without a coherent finite economy.

## Current Verified State

`GameState` stores party levels/xp/hp/mp, inventory, and flags. `Progression`
owns an XP curve and the v1 defeat penalty. Items, abilities, rewards, save
round-trip, and temporary Buddy exist. Real character-art resources are
incomplete as authored recruits and some source references lack shipping
provenance.

## Desired Behavior

- Finite sources and rewards cannot soft-lock required growth.
- Defeat, revival, and downed-member recovery are explicit.
- One real Dungeon Friend exercises the stable field/combat/passive data shape.
- Equipment, currency, shops, and character UI are no broader than the thesis
  requires.
- Source/reference art cannot become shipping content without release
  provenance.

## Decisions And Contracts

- D-028 and D-033 govern.
- The temporary Buddy contract does not become a recruit by inertia.
- Random respawn-farm drop design from T-070 is retired.
- Kayden chooses the defeat penalty, revive rule, currency role, and minimum
  equipment scope before implementation.

## Non-Goals

- Full roster, full economy, crafting tree, broad shop network, stretch gauges,
  or final balance.

## Dependencies And Blockers

- `S-003` persistent resolved state.
- `S-012` production deterministic encounters.
- Kayden progression decisions.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Record Kayden's defeat penalty, revive/downed-member, currency, equipment, and real-recruit scope decisions. | blocked | none | pending |
| TK-002 | Add a failing finite-source reward ledger and implement exact no-grind XP/reward accounting. | ready | S-003, S-012, TK-001 | pending |
| TK-003 | Implement one real recruit data contract with world verb, combat kit, passive/reaction, and stable save identity. | ready | TK-002 | pending |
| TK-004 | Implement the minimum character/equipment/currency surface required by the accepted progression contract. | ready | TK-003 | pending |
| TK-005 | Run and capture the finite-progression and recruitment demo with finite-source accounting proof. | ready | TK-004 | pending |
| TK-006 | Record Kayden's progression-balance and replay-pressure verdict. | blocked | TK-005 | pending |

## Acceptance Criteria

- [ ] Required growth is achievable from finite authored sources.
- [ ] Defeat and downed-member recovery cannot create an unrecoverable state.
- [ ] One real recruit satisfies D-033 and round-trips through save/load.
- [ ] Character/equipment UI exposes only implemented, meaningful choices.
- [ ] Kayden accepts the progression and replay pressure.

## Testing Seams

- Pure reward ledger and progression curve.
- Defeat/revive and save compatibility.
- Recruit/ability/equipment resource validation.
- One-session finite progression demo.

## Verification Procedure

```bash
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Blueprint progression/data decisions, Runbook player loop, README
  current state, and world lore for the authored recruit.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Legacy progression/recruit/art/economy work consolidated | GameState, SaveData, Progression, items, character resources, tests, and asset notes inspected | new stable progression spec | owner fork, dependencies, all slices |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Full roster/economy expansion waits on `S-004` and `S-005`.

## Supersession

- Supersedes: T-056, T-070, T-071, T-076, B-10, and legacy equipment scope
- Superseded by: none
