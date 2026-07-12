# Sol + Fable Unified-World Fix Handoff

**Prepared:** 2026-07-11
**Shared base:** `origin/codex/unified-world-consolidation`
**Review PR:** `#13` -> `integration` (draft; do not merge yet)

These are two bounded prototype revisions from Kayden's consolidation
playtest. They may proceed in parallel because they own separate files. Neither
task promotes a dev spike into production architecture.

## Accepted owner decisions

- Sol's elevation reads without explanatory labels. Preserve its projection,
  geometry, grid, depth, and integer-elevation logic; only colors/palette need
  another pass.
- Four visible followers feel good. Exploration followers stay render-only,
  non-interacting, and pass-through; the leader can move through them.
- Combat remains in the current room, but encounter entry must be unmistakable:
  freeze exploration input, play a short original stinger/visual cue, then show
  turn-based controls and the first intent. Do not swap scenes, cameras, room
  state, or rulesets.
- D-027 is resolved to intent rounds: enemies move or declare, the player sees
  the current exact intent, party members act in any order, enemies resolve,
  then environmental reactions resolve.
- Enemy forecasts use a rolling horizon (prototype default 3). Previously
  shown future verbs remain trustworthy during ordinary refill. Invalid plans
  rebuild from current state. Future UI shows verbs only; current intent shows
  exact cells, damage, and status.
- Combat body blocking should create deliberate spacing tactics, not accidental
  congestion. Formation selection governs preferred starting placement;
  combat occupancy and protection abilities make that placement matter.

## Shared seam - do not duplicate

Sol owns a small pure formation/deployment planner. Its output contract is a
neutral snapshot:

```text
{
  formation_id,
  leader_id,
  facing,
  member_cells: {member_id: cell},
  deployment_cells: {member_id: legal_reachable_cell}
}
```

Fable consumes the member IDs/cells/deployment cells at encounter entry. Fable
must not copy Sol's breadcrumb, formation, or fallback algorithm. Sol must not
edit Fable's encounter phases, intent planner, or combat UI.

## Sol - T-096 selectable formation/deployment contract

**Branch:** `codex/t-096-party-formations` from the shared base.

### Keep

- `VisiblePartyExplorationModel` leader-only occupancy/interaction.
- Leader pass-through and follower-zero-effects tests.
- One-cell breadcrumb compression and recovery.
- All T-086 elevation logic.

The existing `formation_state` values (`spread`, `single_file`, `recovered`)
describe transient movement. They are not selectable formations; keep that
state separate from the new `selected_formation`.

### Implement

- Add a small pure `game/scripts/dev/party_formation_layout.gd`.
- Define exactly three prototype choices: `line`, `square` (2x2), and `spaced`.
- Rotate preferred offsets from leader facing.
- Let the exploration model select/cycle a formation and remember it across
  movement and leader switches.
- Compress through a one-cell choke, then recover toward the selected shape.
- Produce four unique, walkable, reachable encounter-start cells. Keep the
  leader anchored; exclude enemies, props, blocked cells, disconnected cells,
  and illegal elevation jumps. Use a deterministic bounded nearest-valid
  fallback when the ideal shape does not fit.
- Add a dev-only formation selector/label to Sol's party spike. Do not add
  production InputMap actions.
- Palette-only recut of Sol's height scene. Do not change its geometry,
  projection, elevation, occlusion, pathfinding, or depth rules.

### Red/green acceptance

1. Exactly three formations; invalid selection fails closed without mutation.
2. Offsets rotate correctly in four facings and never overlap.
3. The leader can move through visible followers in every formation.
4. Followers never occupy/hold plates, push blocks, interact, or trap leader.
5. Selection survives leader switches and ordinary movement.
6. Every formation compresses through the choke and reforms afterward.
7. Deployment is pure and deterministic, keeps the leader anchored, returns
   four legal distinct reachable cells, and differs by formation when space
   permits.
8. Dense-room fallback never crosses walls/elevation or lands on enemies/props.

### Proof

- Update/extend `test_visible_party_exploration_model.gd`; add and register a
  focused formation-layout suite only if needed.
- Capture line, square, spaced, choke, and recovered states at 1280x720 under
  `docs/screenshots/t096-party-formations/`.
- Run import, full unit suite, and the revised scene boot/capture.
- Append actual proof to `TASKBOARD.md`; never claim tactical combat behavior.

### Out of scope

Encounter cue/audio/UI, enemy intents, guard/shield/breath mechanics, mid-combat
free reformation, save/menu/LDtk production architecture, new input bindings,
high ground/cover, or the T-093 reaction matrix.

## Fable - T-097 encounter cue + intent-round revision

**Branch:** `claude/t-097-encounter-intent-recut` from the shared base.

### Keep

- The current pure intent core and phase order.
- Preview equals result, exact status durations, dodge/body-block/stun/push.
- Stable future-verb-only UI and exact current intent.
- Same-room/camera/position/puzzle-state continuity.

Do not rebuild the working T-092 core. Correct the missing contracts below.

### Implement

- Add an explicit `ENTER` phase to `intent_prototype_spike.gd`:
  immediately gate exploration input, play a short original placeholder sting,
  show a strong `ENCOUNTER / TURN-BASED` visual beat, reveal the combat UI, then
  declare/open the first player phase. Use local gating, not global
  `SceneTree.paused`, so audio/tweens/coroutines cannot deadlock.
- Replace the hard-coded hero/friend action loop with `party_ids`; all four
  visible members get movement/action budgets and may act in arbitrary order.
- Model plan entries with public `verb` plus private planning context. Ordinary
  rolling refill preserves the two previously telegraphed verbs and appends
  only the newly exposed horizon step. Rebuild the full three-step prototype
  plan when its internal target dies/changes or the current head becomes
  illegal. Empty movement is invalid and cannot silently consume a round.
- Future UI must serialize only verbs - never private targets, destinations, or
  cells. Current intent keeps exact cells/damage/status.
- Add one generic gray-box `guarded_cells` effect: facing defines the front,
  front-left, and front-right protected cells for an exact duration. It
  intercepts a line-shaped breath/spit before allies behind it, and preview and
  resolution report the same blocked result. Keep this generic and data-shaped
  so T-093 can later absorb it; do not create a dragon or permanent friend kit.
- Consume Sol's neutral member/deployment snapshot when available. Until the
  branches are merged, keep that adapter tiny and isolated.

### Red/green acceptance

1. Encounter entry gates movement/input until the cue completes and the player
   phase opens; the cue runs once.
2. Scene, camera, party positions, block/chest state, and room instance remain
   unchanged across entry and victory.
3. All four members can move/act and finish a round in arbitrary order.
4. Ordinary refill preserves already-shown verbs; invalid target/head rebuilds
   the full horizon deterministically.
5. An illegal/zero-length move cannot disappear as a consumed action.
6. Future intent presentation never leaks target/cell/private context.
7. Guard intercepts a line attack for exactly its stated duration, then expires.
8. Guard preview equals resolution; moving/pushing/stunning still changes or
   cancels intent as specified.

### Proof

- Extend `test_intent_logic.gd` with strict red/green cases above.
- Extend the scripted windowed tour with encounter-entry, four-unit any-order,
  target-invalidation replan, and guard-vs-line captures under
  `docs/screenshots/t097-intent-recut/` at 1280x720 and 1920x1080.
- Run import, full unit suite, main boot, and both the existing and revised
  intent tours.
- Append actual proof to `TASKBOARD.md`; do not claim final audio/art.

### Out of scope

Production `TurnManager`/`CombatScene` migration, full roster or dragon,
formation algorithm/editor, final audio, high ground/cover/hazards, persistence,
or the full T-093 material/reaction matrix.

## Merge and owner gate

1. Merge T-096 into `codex/unified-world-consolidation` and rerun its pure
   formation tests.
2. Rebase/merge T-097 onto that result, replace its tiny snapshot adapter with
   Sol's actual neutral planner output, and rerun the combined battery.
3. Kayden replays: three formations through the choke; encounter entry;
   arbitrary four-member order; invalidated three-verb plan; guard blocking a
   breath-like line.
4. Only after that replay passes does T-093 begin. Neither task merges directly
   into `integration`; draft PR #13 remains the review gate.
