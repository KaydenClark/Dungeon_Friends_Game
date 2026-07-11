# Terra 5.6 Ultra Plan - Authored Combat Arenas

## Mission

Complete the Phase 4 authored-arena lane, T-072 through T-075, so touching an
overworld enemy opens one of several prebuilt, editable, biome-appropriate
battle maps instead of copying a small patch of the contact area.

This is an implementation brief for Terra 5.6 in Ultra mode. Execute the work;
do not stop after producing another plan.

## Read First

Read these sources in authority order before editing:

1. `AGENTS.md`
2. `BLUEPRINT.md`, especially D-018, Party And Combat Model, Core Logic And
   Invariants, Non-Goals, and Design Decisions
3. `TASKBOARD.md`, especially T-072 through T-075 and T-069
4. `RUNBOOK.md`, especially Test And Build, Phase 4 combat check, and Version
   Control
5. The live combat, encounter, save/load, LDtk, and test code touched by the
   tasks

Trust verified project behavior over stale prose and update stale docs when
this lane touches them.

## Safety And Branch Boundary

- The current checkout may contain unrelated QA-audit work. Inspect `git
  status`, the current branch, and the diff before doing anything.
- Do not overwrite, stash, commit, or fold unrelated changes into this lane.
  If no clean task worktree/branch is available, stop and ask Kayden for one.
- Work from `integration` on one milestone branch, suggested name:
  `feat/t072-t075-authored-arenas`.
- Never edit `game/addons/`, never merge into `main`, and never force-push.
- Mark T-072 `in-progress` before implementation. Keep T-072..T-075 statuses
  accurate as proof is earned; append proof rows and never rewrite history.

## Locked Product Contract

Implement D-018 as written. Do not reopen its product decisions:

- Battle topology comes from authored LDtk templates, not literal nearby
  overworld cells and not runtime procedural generation.
- The first forest pool has seven arenas: 2 `empty`, 3 `mid`, 2 `hard`.
- Per-template weights begin at `5` for empty, `2` for mid, and `1` for hard.
  These produce a tunable initial tier mix of roughly 56% / 33% / 11%.
- Eligible arenas are filtered by biome/tags. Contact direction orients
  deployment. Enemy count and strength remain independent of arena tier.
- Selection is deterministic, survives save/load, and cannot be rerolled by
  reloading. No immediate arena repeat.
- Boss encounters may pin a dedicated arena.
- Arenas import as `TileMapLayer`; deprecated `TileMap` is forbidden.
- Allied collision remains intentional after deployment. Validation prevents
  unavoidable spawn traps; it does not make allies pass through each other.
- Combat remains grid-snapped, no-diagonal `AStarGrid2D`, with the existing
  two-layer FSM and `TurnManager` intact.
- Do not add flanking, terrain bonuses, procedural arena generation, new enemy
  AI, or other Deferred/Stretch systems.

## Definition Of Done

Touching forest enemies selects and loads one of seven authored forest arenas.
The arena is editable in LDtk, visually fills the established 17x7 tactical
board, deploys both sides according to contact orientation, and is always
fightable for up to 4v4. Reloading a save cannot reroll the next arena. Kayden
can cycle through the complete pool in under one minute with each arena's id,
tier, weight, biome, and tags visible.

T-069 remains Kayden's windowed acceptance gate; do not mark it complete.

## Execution Plan

### Stage 0 - Baseline And Dependency Trace

1. Inspect the dirty tree and branch boundary described above.
2. Run the current baseline commands from `RUNBOOK.md`: import, unit suite,
   slice smoke, and main-scene one-frame boot. Record the actual counts; do not
   copy old counts from docs.
3. Trace the current production path from overworld contact through
   `SceneManager._arena_from_room`, `CombatScene.setup`, unit placement, arena
   rendering, `EncounterData`, `GameState`, `SaveData`, `SaveManager`, LDtk
   import/adoption, and the registered test suites.
4. Identify the smallest seam that lets both production combat and the gallery
   consume one arena representation. Avoid a broad combat rewrite.

### Stage 1 - T-072: Arena Data And Deterministic Selector

Use strict red/green/refactor.

Write failing tests first for:

- exact weighted ticket counts for the seven records;
- biome/tag eligibility filtering;
- deterministic draw order for a known seed;
- no immediate repeat, including across a refill boundary;
- deterministic bag refill;
- empty-eligibility and invalid-record handling with explicit errors/fallback;
- save/load continuation producing the same next draw as an uninterrupted run;
- fixed-arena override validation.

Then implement the smallest production classes:

- An authored `Resource` arena record with stable id, biome/tags, tier, weight,
  LDtk level id/path, mirror-safe flag, party deployment zone, and enemy
  deployment zone.
- A registry/library that validates unique ids and resolves records.
- A pure deterministic weighted shuffle-bag selector. Persist compact state in
  the existing single-source session/save model, preferably seed plus draw
  counter only if replaying those values exactly reconstructs refill and
  no-repeat state. Otherwise store the smallest explicit state that does.
- Backward-compatible loading for existing schema-version-1 saves. If a schema
  bump is necessary, add a tolerant migration rather than invalidating saves.

Keep selection logic independent from Godot scene rendering so tests exercise
the same callable code production uses.

Stage gate: focused selector/save tests pass, followed by the full unit suite.
Update T-072 status and append real proof only after the gate passes.

### Stage 2 - T-073: Seven Editable Forest Arenas

Author one LDtk battle-arena project or the smallest extension of an existing
project that keeps all seven levels visible and editable together.

Create named, stable templates:

- 2 empty: open fields with zero to two standalone trees;
- 3 mid: meaningful cover with at least two generous routes between sides;
- 2 hard: visually distinct/scary layouts with constrained choices but no
  forced opening trap or disconnected side.

For every arena:

- Preserve the current 17x7 combat-grid contract unless verified live code
  requires a documented adjustment.
- Use explicit LDtk entities/fields for party and enemy deployment zones.
- Use the promoted runtime forest tiles and `TileMapLayer` output.
- Give the record stable biome/tag/tier/weight metadata.
- Keep at least eight legal deployment cells per side so a 4v4 does not depend
  on a lucky ordering.
- Ensure every deployed unit can ultimately reach a legal attack position
  against the other side under no-diagonal movement.

Do not judge only from JSON. Import the project, load every resulting level,
and generate a labeled seven-arena contact sheet or gallery capture.

Stage gate: clean import, all seven resolve through the registry, no deprecated
`TileMap`, initial validator rules pass, and the contact sheet is visually
inspected. Then update T-073 with actual proof.

### Stage 3 - T-074: Replace The Production Arena Source

Write failing integration tests first for:

- a forest encounter never selecting a non-forest arena;
- encounter tags narrowing the eligible pool;
- contact from opposite sides swapping/orienting deployment correctly;
- fixed boss arena override;
- enemy-group composition staying identical when arena tier changes;
- the selected arena record reaching the live combat setup and renderer;
- old saves/default encounters receiving a safe forest-compatible default.

Then:

1. Extend `EncounterData` with biome/tags and an optional fixed arena id.
2. Pass contact orientation and selection context through the existing
   SceneManager combat-entry seam.
3. Load the chosen authored LDtk arena into the same runtime arena shape used
   by pathfinding, placement, highlighting, and rendering.
4. Make deployment consume the authored zones instead of assuming hard-coded
   left/right columns. Mirror only records marked mirror-safe; otherwise map
   contact direction to the authored side without mutating topology.
5. Remove `_arena_from_room` from the production path. Delete it only after no
   tests/dev tools require it; do not leave stale comments claiming local
   terrain is still copied.
6. Preserve the existing FSM, TurnManager, combat math, commands, rewards,
   zoom/return flow, and exact-position overworld restoration.

Stage gate: focused integration tests, full unit suite, and slice smoke all
pass. Manually enter encounters from more than one approach direction and
confirm the chosen id and deployment orientation in the debug display. Then
update T-074 with actual proof.

### Stage 4 - T-075: Safety Validator And Gallery

Write negative fixtures first and prove each fails for the expected reason:

- disconnected party/enemy deployment regions;
- fewer than four legal cells in either zone or fewer than eight available
  cells where the adopted deployment contract requires that capacity;
- blocked/overlapping deployment cells;
- Hero with fewer than two legal first-move directions;
- an allied deployment ordering that creates an unavoidable opening softlock;
- no reachable attack position between the two sides;
- ordinary arena exceeding the agreed cover budget;
- duplicate id, missing LDtk level, invalid tier/weight, or biome/tag mismatch.

Implement one reusable validator used by tests and the authoring/gallery tool.
Do not maintain a second, weaker gallery-only validation path.

Add a one-command dev scene or an F1 gallery that:

- cycles all eligible arenas without starting a normal encounter;
- supports previous/next and biome/tag filtering;
- shows id, tier, weight, biome, tags, fixed/mirror-safe state, and validation
  result;
- renders party/enemy deployment zones distinctly;
- can produce the labeled seven-arena contact sheet used as the demo artifact.

Document exact edit, import, validate, and preview commands in `RUNBOOK.md`.

Stage gate: every negative fixture fails correctly, every production arena
passes, gallery capture is generated and visually inspected, full tests and
slice smoke are green, and main boots clean. Update T-075 and append the proof
row with the gallery artifact path.

### Stage 5 - Documentation, Cleanup, And Handoff

1. Update `BLUEPRINT.md` only for the implemented arena contract and any
   verified architectural detail; do not reopen D-018.
2. Update `RUNBOOK.md` to replace stale D-012/local-terrain instructions with
   arena editing, validation, gallery, and T-069 play-check steps.
3. Update `README.md` if its public combat description still says terrain is
   copied from the contact point.
4. Update `TASKBOARD.md` statuses and append one proof row per completed task
   or one clearly partitioned milestone proof row. Never rewrite prior rows.
5. Scan code and current docs for stale production claims such as
   `local-terrain`, `D-012`, and `_arena_from_room`; preserve historical proof
   text but correct current contracts.
6. Review the diff for accidental QA-branch changes, add-on edits, generated
   import/cache files, or scope creep.

## Required Final Verification

Use the exact current Windows/Godot 4.7 commands from `RUNBOOK.md`, not stale
macOS examples or remembered test counts.

At minimum, record actual results for:

1. Godot headless import.
2. Relevant red/green selector, persistence, loader, validator, and combat
   integration tests.
3. Full first-party unit suite.
4. Full slice smoke test; run 5/5 if the combat acceptance policy still
   requires it when reached.
5. `main.tscn --quit-after 1` boot.
6. Gallery/contact-sheet generation and visual inspection of all seven arenas.
7. Manual windowed encounters from multiple contact directions, including an
   empty, mid, and hard arena if debug selection is available.
8. Save before the next draw, reload, and confirm the same next arena appears.
9. A 4v4 validation/setup check even though the shipped test party is smaller.

Do not claim T-069 accepted; hand that final windowed feel/readability verdict
to Kayden.

## Commit And PR Shape

Prefer four reviewable commits on the milestone branch:

1. `T-072: add deterministic authored arena selection`
2. `T-073: author the forest battle arena pool`
3. `T-074: load authored arenas in production combat`
4. `T-075: add arena validation and gallery tooling`

Add a final documentation-only commit only if the doc changes are too broad to
belong with their owning implementation commits. Open a PR targeting
`integration`; do not merge it. The PR description must state what changed,
why, risks/side effects, exact verification results, demo artifact paths, and
that T-069 remains Kayden-owned.

## Stop Conditions

Stop and record the blocker if:

- the task cannot be isolated from the current dirty QA branch;
- implementing the templates would require hand-editing `game/addons/`;
- a verified LDtk importer limitation forces a public data-layout or locked
  architecture change;
- the same verification fails twice and the next step is not clearly safe;
- any proposal would change D-018, ally collision, grid movement, party size,
  the single-Autoload rule, or the `integration`/`main` boundary.

Otherwise make reasonable low-risk decisions, document them briefly, and keep
moving until T-072 through T-075 have real proof.

## Final Report Format

Return concise bullets under exactly these headings:

1. What changed
2. Why it changed
3. Risks or side effects
4. How it was verified
5. Kayden's remaining T-069 checks

Include exact files, actual test counts, the gallery/contact-sheet path, branch
and PR state, and any uncertainty. Do not report unrun checks as green.
