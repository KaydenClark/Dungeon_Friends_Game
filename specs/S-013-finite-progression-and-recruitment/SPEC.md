# S-013 - Finite Progression And Recruitment

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-013
**Status:** active
**Priority:** 2
**Owner:** claude-engineer
**Updated:** 2026-07-20
**Catalog description:** Define and implement finite no-grind progression, defeat/revive rules, one real recruit, equipment/economy seams, and the character surface.
**Blockers:** none
**Latest event:** TK-005 closed with proof.
**Next gate:** Complete TK-006.

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
- The defeat penalty, revive rule, currency role, and minimum equipment scope
  are resolved before implementation. Per D-038 (2026-07-19) an Engineer makes
  these calls from Blueprint canon (D-028's finite economy plus the flagged
  D-008 review), records them as flagged Blueprint decision rows, and Kayden
  reviews them in the S-004 batch replay.

## Non-Goals

- Full roster, full economy, crafting tree, broad shop network, stretch gauges,
  or final balance.

## Dependencies And Blockers

- `S-003` persistent resolved state.
- `S-012` production deterministic encounters.
- Progression-fork decisions recorded per D-038 (Engineer-resolved, flagged for
  the S-004 batch review).

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Resolve the progression fork per Blueprint canon under D-038: record defeat penalty, revive/downed-member, currency, equipment, and real-recruit scope as flagged Blueprint decision rows for the S-004 batch review. | done | none | progression fork resolved as flagged Blueprint row D-043 grounded in D-028 (finite economy, flagged D-008 review), D-033 (roster/kit scope), and the tuned D-014/D-015 checkpoint feel: XP-loss penalty retired (soft-lock risk), KO+self-revive-at-1HP downed rule, no thesis currency, item-flag equipment surface, one real recruit replacing companion_test; docs-only slice, no behavior change, doctor green |
| TK-002 | Add a failing finite-source reward ledger and implement exact no-grind XP/reward accounting. | done | TK-001 | red: 3 script-error aborts on the missing ledger APIs; green: unit 48 suites/375 tests/2509 checks PASS with 0 script errors; slice smoke 134/134 (v1 fallback incl. its kept penalty); both batteries green; boot clean; claim_reward_source pays each finite source exactly once and rides the save schema with legacy defaults; the unified victory path claims its stable world_key#encounter source before paying; apply_defeat_xp_penalty returns 0 under the v2 default (D-043) while the v1 fallback keeps the tuned D-014 rule the smoke pins |
| TK-003 | Implement one real recruit data contract with world verb, combat kit, passive/reaction, and stable save identity. | done | TK-002 | green first pass: unit 49 suites/379 tests/2534 checks PASS with 0 script errors; slice smoke 134/134; boot clean; Wren ships the full D-033 friend contract - grow world verb through the shared S-011 seam (lore: the first friend is Growth-oriented), Strike+Verdant Growth kit, verdant_mender passive honored deterministically by the promoted environment tick, Kenney CC0 placeholder frames (art flagged as tunable), stable save identity; recruit_member is fail-closed (dup/unknown/full-party refused) and itself a finite ledger source; a recruited Wren walks as a visible follower and fields as a combat unit |
| TK-004 | Implement the minimum character/equipment/currency surface required by the accepted progression contract. | done | TK-003 | green: unit 49 suites/382 tests/2550 checks PASS with 0 script errors; slice smoke 134/134; boot clean; cast_ability action (5/R1) casts the LEADER's field verb at the faced cell in exploration and the ACTIVE unit's verb toward the enemy in encounters, both through the shared ReactionCaster seam with MP spend, action consumption, and named toasted refusals (no verb, not enough MP); per D-043 no currency or loadout UI exists to build - the roster-driven HUD, item-flag equipment, and these controls are the whole accepted surface |
| TK-005 | Run and capture the finite-progression and recruitment demo with finite-source accounting proof. | done | TK-004 | windowed progression_demo 13/13 PASS with 3 captures docs/screenshots/s013-progression: Wren recruits once (second recruit refused), a party of three walks, her field verb grows a vine, the slime victory pays +5 XP exactly once, the ledger refuses the double-pay, defeat costs 0 XP under D-043, and the roster + claimed ledger survive a real JSON save round trip; unit 49 suites/382 tests/2550 checks PASS; slice smoke 134/134 |
| TK-006 | Owner progression-balance and replay-pressure verdict - consolidated into the S-004 thesis replay per D-038 (2026-07-19); TK-005's demo feeds that batch review. | deferred | S-004 | owner verdict batches at S-004 per D-038 |

## Acceptance Criteria

- [ ] Required growth is achievable from finite authored sources.
- [ ] Defeat and downed-member recovery cannot create an unrecoverable state.
- [ ] One real recruit satisfies D-033 and round-trips through save/load.
- [ ] Character/equipment UI exposes only implemented, meaningful choices.
- [ ] Finite-progression and recruitment demo captured for the S-004 batch review; the owner balance verdict rides that replay (D-038).

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
| 2026-07-19 | TK-001/TK-006 | D-038 owner-approval consolidation: TK-001's progression fork becomes Engineer-resolved per Blueprint canon with flagged decision rows; TK-006's balance verdict batches into the S-004 thesis replay | Kayden chat directive 2026-07-19; Blueprint D-038 row | this spec, Blueprint | TK-001 through TK-005 |
| 2026-07-20 | TK-001 | Ticket closed | progression fork resolved as flagged Blueprint row D-043 grounded in D-028 (finite economy, flagged D-008 review), D-033 (roster/kit scope), and the tuned D-014/D-015 checkpoint feel: XP-loss penalty retired (soft-lock risk), KO+self-revive-at-1HP downed rule, no thesis currency, item-flag equipment surface, one real recruit replacing companion_test; docs-only slice, no behavior change, doctor green | Blueprint D-043 flagged row; spec Decisions And Contracts already anticipated this path | TK-002 finite-source ledger implements the accepted contract (including removing the 25% XP penalty in code); TK-003 real recruit; TK-004 minimum surface; TK-005 demo |
| 2026-07-20 | TK-002 | Ticket closed | red: 3 script-error aborts on the missing ledger APIs; green: unit 48 suites/375 tests/2509 checks PASS with 0 script errors; slice smoke 134/134 (v1 fallback incl. its kept penalty); both batteries green; boot clean; claim_reward_source pays each finite source exactly once and rides the save schema with legacy defaults; the unified victory path claims its stable world_key#encounter source before paying; apply_defeat_xp_penalty returns 0 under the v2 default (D-043) while the v1 fallback keeps the tuned D-014 rule the smoke pins | GameState/SaveData ledger docs; scene_manager penalty comment records the D-043 gate; RUNBOOK tally | chests/quests still dedup via their v1 flag mechanisms rather than the ledger (extensible later); TK-003 real recruit next |
| 2026-07-20 | TK-003 | Ticket closed | green first pass: unit 49 suites/379 tests/2534 checks PASS with 0 script errors; slice smoke 134/134; boot clean; Wren ships the full D-033 friend contract - grow world verb through the shared S-011 seam (lore: the first friend is Growth-oriented), Strike+Verdant Growth kit, verdant_mender passive honored deterministically by the promoted environment tick, Kenney CC0 placeholder frames (art flagged as tunable), stable save identity; recruit_member is fail-closed (dup/unknown/full-party refused) and itself a finite ledger source; a recruited Wren walks as a visible follower and fields as a combat unit | CharacterStats passive_id doc; recruit contract in scene_manager; Wiki-facing lore untouched (names remain open canon; Wren flagged for the batch review) | TK-004 exposes a player-facing cast control for recruit verbs (kit currently API/tests/demo only); Wren's bespoke art + recruitment story are S-014/S-004 content |
| 2026-07-20 | TK-004 | Ticket closed | green: unit 49 suites/382 tests/2550 checks PASS with 0 script errors; slice smoke 134/134; boot clean; cast_ability action (5/R1) casts the LEADER's field verb at the faced cell in exploration and the ACTIVE unit's verb toward the enemy in encounters, both through the shared ReactionCaster seam with MP spend, action consumption, and named toasted refusals (no verb, not enough MP); per D-043 no currency or loadout UI exists to build - the roster-driven HUD, item-flag equipment, and these controls are the whole accepted surface | RUNBOOK exploration + encounter control lines; input_prompts label | TK-005 finite-progression + recruitment demo with accounting proof |
| 2026-07-20 | TK-005 | Ticket closed | windowed progression_demo 13/13 PASS with 3 captures docs/screenshots/s013-progression: Wren recruits once (second recruit refused), a party of three walks, her field verb grows a vine, the slime victory pays +5 XP exactly once, the ledger refuses the double-pay, defeat costs 0 XP under D-043, and the roster + claimed ledger survive a real JSON save round trip; unit 49 suites/382 tests/2550 checks PASS; slice smoke 134/134 | RUNBOOK demo command | TK-006 owner balance verdict batches at the S-004 thesis replay per D-038 |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Full roster/economy expansion waits on `S-004` and `S-005`.

## Supersession

- Supersedes: T-056, T-070, T-071, T-076, B-10, and legacy equipment scope
- Superseded by: none
