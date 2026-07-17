# S-015 - Steam Release Proof

> Generated from LLM Workbench v2.3. This stable path never moves.

**Spec ID:** S-015
**Status:** planned
**Priority:** 4
**Owner:** Kayden
**Updated:** 2026-07-17
**Catalog description:** Produce a reproducible, license-safe, controller-checked Steam-first release candidate and owner approval without authorizing publication.
**Blockers:** S-004, S-005
**Latest event:** Release, export, provenance, clean-clone, performance, save-recovery, and owner gates were extracted from canon and legacy evidence.
**Next gate:** Complete S-004 and S-005, then an Engineer claims TK-001; Kayden owns the blocked TK-005 release-candidate verdict.

## Outcome

One exact commit produces a desktop release candidate that can be rebuilt from a
clean clone, completes the verified opening route on supported PC inputs and
displays, contains only shippable assets, preserves save/recovery boundaries,
and has Kayden's explicit release-candidate approval.

## Why It Matters

Steam-first is a product decision, not proof that the game is shippable. The
repo currently has no export presets or release candidate, and some internal
reference assets have unknown third-party licensing.

## Current Verified State

Godot 4.7 desktop development runs green. Kenney runtime assets are CC0 with
licenses preserved. Some concept/reference art is internal-only pending
provenance. Debug tools exist and must stay out of release exports. Android
export/touch work is postponed by D-032.

## Desired Behavior

- macOS and Windows desktop export presets are reproducible for the exact RC.
- A clean clone reproduces lifecycle and game verification.
- Shipping assets have documented provenance and attribution requirements.
- Debug/dev-only paths, secrets, signing material, and internal references are
  absent from the release.
- Controller, display, performance, save upgrade/recovery, and rollback checks
  pass.

## Decisions And Contracts

- Steam-first desktop only; mobile/touch remains explicitly postponed.
- Publication, paid signing/notarization, store submission, and credentials
  require separate explicit authorization.
- No license claim is inferred for unknown reference material.

## Non-Goals

- Public deployment, store-page publication, paid certificates, mobile release,
  market-fit claims, or content beyond the accepted release candidate.

## Dependencies And Blockers

- `S-004` owner-accepted thesis slice.
- `S-005` external playtest synthesis.

## Vertical Implementation Slices

| Ticket | Slice | Status | Blockers | Proof |
|---|---|---|---|---|
| TK-001 | Define the exact RC commit, desktop export presets, artifact naming, and release verification manifest. | ready | S-004, S-005 | pending |
| TK-002 | Prove clean-clone setup, lifecycle checks, full tests, and reproducible macOS/Windows exports. | ready | TK-001 | pending |
| TK-003 | Audit licenses/provenance and exclude internal references, dev/debug content, secrets, and signing material. | ready | TK-002 | pending |
| TK-004 | Run controller, display, performance, save compatibility/recovery, install, and rollback checks on the RC. | ready | TK-003 | pending |
| TK-005 | Record Kayden's release-candidate verdict and exact remaining publication gates. | blocked | TK-004 | pending |

## Acceptance Criteria

- [ ] Exact commit and artifacts are reproducible from a clean clone.
- [ ] macOS and Windows desktop candidates pass the release manifest.
- [ ] Every shipping asset has acceptable provenance.
- [ ] Debug/internal/sensitive content is absent.
- [ ] Controller, displays, performance, save recovery, and rollback pass.
- [ ] Kayden approves the RC; no publication is implied.

## Testing Seams

- Clean-clone lifecycle and full Godot verification.
- Export artifact manifest/checksums.
- License/provenance and forbidden-file scans.
- Desktop install/run/controller/display/save-recovery matrix.

## Verification Procedure

```bash
node tools/spec-workbench.mjs doctor
node tools/spec-workbench.mjs next --json
cd game
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/run_tests.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/dev/slice_smoke_test.tscn
```

## Documentation Impact

- Update Runbook release/export/recovery instructions, README supported
  platforms/credits, Blueprint deployment truth, and this spec's artifact log.

## Append-Only Evidence And Execution Log

| Date | Ticket | Event | Verification | Docs | Remaining gap |
|---|---|---|---|---|---|
| 2026-07-17 | spec | Steam-first release proof promoted from D-032 and legacy export/assets | project settings, gitignore, assets/licenses, runbook, and source manifests inspected | new stable release spec | dependencies and all slices |

## Completion Result

Pending.

## Remaining Limitations Or Follow-Up Specs

- Store submission/publication is a separate owner-authorized action.
- Mobile release requires a future spec after PC proof.

## Supersession

- Supersedes: T-002 desktop portion, B-21 acknowledgement, and diffuse release-readiness evidence
- Superseded by: none
