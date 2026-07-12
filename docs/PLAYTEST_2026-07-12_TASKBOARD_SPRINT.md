# Taskboard Sprint Playtest - 2026-07-12

## Scope

- Branch: `codex/taskboard-sprint`
- Runtime: Godot 4.7 on macOS / Apple M4 / Metal Forward Mobile
- Focus: T-093 reaction room, current production slice regression, and
  ungated ready bugs that do not require a product decision.

## Windowed Pass

The reaction room was opened as a real 1280x720 Godot window. The initial
actionable state rendered correctly. Keyboard input was used to open Grow
targeting, aim at the authored soil cell, commit Grow, then open Fire targeting
on the same cell and commit the burn. The same scene's deterministic windowed
tours exercised the complete route at 1280x720 and 1920x1080: materials,
grow/burn, air spread, flood/freeze, wet conduction, smoke clearing, encounter
cue, four-unit intent round, exact spark preview, intent cancellation, victory,
and persistent room state.

## Findings

| Severity | Finding | Result |
|---|---|---|
| Medium | B-22: the consequence preview text collided with HP labels and units at 1920x1080. | Fixed with a backed, viewport-contained panel; strict layout checks and both capture sizes are green. |
| Medium | B-15: New Game followed by a crystal save could silently overwrite slot 1. | Fixed. The save boundary now refuses unconfirmed replacement, and the crystal offers Overwrite / Keep Save. |
| Medium | B-23: Metal viewport readback sometimes wrote proof PNGs with large black holes despite a complete live window. | Fixed. The tour rejects incomplete coverage, refreshes the inherited CanvasItems, synchronizes the renderer, and retries before saving. |
| Low | The transient consequence panel still covers part of the upper-right playfield while aiming at 1280x720. | Accepted for this gray-box spike because the panel is readable, disappears on commit/cancel, and exact previews are the prototype's purpose. Production UI should dock or condense it. |
| Product gate | Exploration reactions do not damage/aggro units; fire/smoke/wet do not decay; range has no cost/cooldown; every unit temporarily has every verb. | Not changed. These are T-093 fun/balance questions requiring Kayden's verdict, not correctness bugs. |

## Verification Notes

- B-22 red: the reaction-room suite failed to compile because the required
  viewport layout seam did not exist. Green: the helper and panel landed;
  `test_reaction_room_logic` now covers supported viewport containment.
- B-15 red: the load-flow suite failed against the missing guarded-save API.
  Green: a fresh session cannot replace an occupied slot without the explicit
  overwrite flag; the old XP snapshot remains intact after refusal and changes
  only after confirmation.
- B-23 red: the first strict capture pass rejected the known-bad preview and
  victory frames. Green: both supported resolutions now finish with complete
  previews/victory PNGs; the coverage classifier has a negative unit case.
- Known test diagnostics remain: intentional corrupt-save parsing, invalid-map,
  bad pressure-plate wiring warnings, and Godot shutdown leak messages. None
  produced a failed check.

## Remaining Gate

T-093 still requires Kayden's interactive fun/not-fun verdict before T-091
persistence and the later v2 pivot tasks can be marked ready in practice.
