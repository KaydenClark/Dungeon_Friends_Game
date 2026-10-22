# Research Audit: Retro Cross-Platform RPG Toolchain & Design

Audit date: 2026-06-10
Auditor: Claude (Cowork), on behalf of Kayden
Source documents audited:
- `2D Retro Game Development Tools.docx` (Gemini, hereafter "Doc A — Tools")
- `Retro Cross-Platform Game Design.docx` (Gemini, hereafter "Doc B — Design")

Project: Dungeon Friends Game (`https://github.com/KaydenClark/Dungeon_Friends_Game`) — a Game Boy-inspired 2D Zelda-style overworld/dungeon adventure with party collection and turn-based combat, built mostly solo with AI-assisted coding, targeting macOS, Windows, and Android.

---

## 1. Executive Summary

Both documents converge on the same headline recommendation — **Godot 4.x, LDtk for levels, Pixelorama/Aseprite for art, Furnace for audio** — and that headline recommendation holds up under verification. The core engineering guidance (TileMapLayer, AStarGrid2D with Manhattan heuristic, nearest-neighbor filtering, integer scaling, Resource-based data, FSM-driven combat, SceneManager context passing) is technically sound and matches current Godot 4 documentation as of Godot 4.6.x (June 2026).

However, both documents oversell certainty in places, contain at least one internally inconsistent hardware claim, cite at least one workflow that is now outdated (Godot 4.5+ removed the rcedit/Wine requirement for Windows icon embedding), and recommend a shader technique (`SCREEN_TEXTURE` / `hint_screen_texture`) that has a known rendering bug specifically on the Compatibility renderer both documents otherwise recommend for low-end Android. Neither document seriously grapples with the actual scope risk for a solo, AI-assisted developer: the *design* document (Doc B) in particular describes a feature set (Lufia II-style visible synchronized enemies + Golden Sun-style elemental traversal abilities + Ikari/Djinn-style risk-reward mechanics + a 100-floor roguelike postgame) that is far beyond a realistic MVP and is presented with no scope triage.

**Bottom line:** the toolchain recommendation is correct and you should proceed with it. The design document's *aesthetic and engine-architecture* sections are largely correct and useful. Its *gameplay scope* sections describe a 3-5 year feature list as if it were a starting point — treat it as a menu of stretch goals, not a spec.

---

## 2. Source Document Summary

### Doc A — "2D Retro Game Development Tools" (Architectural Engineering and Toolchain Optimization)
Focuses on engine selection (Godot vs Unity vs Unreal vs GameMaker vs Defold), the 2D asset toolchain (Pixen/Pixelorama for art, LDtk for levels, Furnace for audio), rendering configuration for a Game Boy aesthetic (nearest filtering, viewport stretch + integer scaling, 4-color palette shader), overworld architecture (grid movement, AStarGrid2D pathfinding, Zelda-style room transitions), and combat/scene architecture (Resource-based stats, FSM combat, SceneManager context passing vs Autoload singletons).

### Doc B — "Retro Cross-Platform Game Design" (Architectural and Design Paradigms)
Focuses on engine selection (Godot vs Defold vs GB Studio), authentic Game Boy hardware constraints (160x144 resolution, 4-color palette, tile/sprite memory limits, 4-channel audio), pixel-perfect rendering techniques including sub-pixel camera smoothing, gameplay design patterns drawn from Lufia II, Golden Sun, Super Mario RPG, Paper Mario, and Into the Breach, and cross-platform export pipelines for macOS, Windows, and Android from an Apple Silicon Mac.

Both documents are AI-generated literature reviews with "Works cited" sections. Citations are a mix of official docs, Reddit/forum threads, YouTube tutorials, and marketing/blog content — treat citation *presence* as a signal of "this claim is googleable," not as a guarantee of accuracy.

---

## 3. Claims Confirmed Accurate

| # | Claim | Source | Verification |
|---|---|---|---|
| 1 | Godot 4.x is MIT-licensed, free, open source, with a native 2D rendering pipeline and no royalties | A | Confirmed against godotengine.org and Godot docs. Current stable is 4.6.3 (Jan–Jun 2026 release cycle). |
| 2 | Godot runs natively on Apple Silicon (no Rosetta) | A, B | Confirmed — native ARM64 support since Godot 3.4. |
| 3 | `TileMap` is deprecated in favor of `TileMapLayer` as of Godot 4.3 | A | Confirmed via Godot 4.3 migration notes and docs. New projects should use `TileMapLayer` directly. |
| 4 | Godot stretch modes `viewport` and `canvas_items` exist and behave as described (viewport = render-then-scale; canvas_items = scale elements, render at native res) | A, B | Confirmed in `docs.godotengine.org/.../multiple_resolutions.html`. |
| 5 | Integer scaling mode is a real Godot feature that prevents uneven "fat pixel" scaling | A, B | Confirmed — integer scaling shipped as part of the Godot 4.3 stretch overhaul. |
| 6 | `AStarGrid2D` exists, supports `diagonal_mode = DIAGONAL_MODE_NEVER` for strict 4-directional movement, and supports a Manhattan heuristic intended for orthogonal grids | A | Confirmed against the official `AStarGrid2D` class docs. This is the correct, idiomatic Godot 4 tool for grid pathfinding. |
| 7 | `SCREEN_TEXTURE` / `hint_screen_texture` is real syntax for a `canvas_item` shader to read the rendered frame for a palette-swap post-process | A, B | Confirmed in Godot's "Screen-reading shaders" docs — **but see §4 for an important caveat about the Compatibility renderer.** |
| 8 | "GL Compatibility" / "Compatibility" renderer exists and is the lowest-overhead option for old Android hardware | A | Confirmed — Godot 4.x ships Forward+, Mobile, and Compatibility renderers; Compatibility uses OpenGL ES3 and is the most broadly compatible. |
| 9 | Pixelorama is free, open source (MIT), built with Godot itself, runs on Win/Mac/Linux/Web, and includes tilemap-layer support plus pixel-art-specific scaling algorithms (cleanEdge, OmniScale) | A | Confirmed via Orama-Interactive/Pixelorama GitHub and godotengine.org showcase. |
| 10 | A maintained LDtk → Godot 4 importer exists (`heygleeson/godot-ldtk-importer`), supports post-import scripts at Entity/Level/World scope, auto-generates TileSets and preserves manual edits across re-imports | A | Confirmed — actively maintained, available on the Godot Asset Library and itch.io. |
| 11 | LDtk uses IntGrid layers (logical integer values per cell) and AutoLayer rules to separate visual tiles from logical/collision data | A | Confirmed against ldtk.io official docs. |
| 12 | Furnace Tracker is free, open source (GPL), cross-platform (Win/Mac/Linux), and emulates the Game Boy DMG chip's 2 pulse + 1 wave + 1 noise channels; DefleMask is a paid Steam product and the spiritual predecessor Furnace was built to replace | A | Confirmed via tildearrow/furnace GitHub and DefleMask's own Steam listing. |
| 13 | Pixen is still actively available and maintained on the Mac App Store (not abandoned), native Mac app with Dark Mode/Sidecar/Quick Look support | A | Confirmed — "Pixen 6" is current. |
| 14 | Game Boy hardware: 40 sprites max in OAM, hard limit of 10 sprites per scanline, causing flicker if exceeded | B | Confirmed against Pan Docs (gbdev.io) — this is accurate and well documented. |
| 15 | Game Boy hardware: tile data lives at $8000-$97FF (6,144 bytes = 384 tiles for DMG), with two overlapping addressing modes ("8000 method" unsigned, "8800 method" signed) sharing a middle block | B | Confirmed against Pan Docs — the *mechanism* described (8000/8800 addressing, 384 active tiles for DMG) is correct. (See §4 for the inconsistency in the *total tile count* figure given earlier in the same document.) |
| 16 | GB Studio 4.x is real, actively developed (4.3.0 shipped in 2026), exports to ROM or Web only — no native Android/iOS/desktop export, no native touch UI | B | Confirmed via chrismaltby.itch.io and gbstudio.dev. This supports Doc B's conclusion that GB Studio is too limiting for this project's cross-platform/touch requirements. |
| 17 | Godot Android export requires OpenJDK 17, the Android SDK with Platform-Tools, and a signed keystore (keytool) for release builds | B | Confirmed against current Godot Android export docs. |
| 18 | macOS distribution outside the App Store requires an Apple Developer ID certificate and Apple notarization (Gatekeeper) | B | Confirmed — and worth flagging explicitly as a **cost**: Apple Developer Program membership is $99/year. Neither document mentions this cost. |
| 19 | Aseprite is a $20 one-time purchase, not a subscription | (verification addition) | Confirmed — relevant because Doc A frames Pixen/Pixelorama as the only real options; Aseprite is the de facto industry-standard pixel art tool and is cheap, cross-platform, and has the best sprite-sheet/animation tooling of the three. |

---

## 4. Claims That Are Partially Accurate But Need Nuance

| # | Claim | Source | Nuance |
|---|---|---|---|
| 1 | "The shader algorithm... reads SCREEN_TEXTURE... use a custom ShaderMaterial on a ColorRect inside a CanvasLayer" for the 4-color palette effect | A, B | Mechanically correct, **but** there is a documented Godot issue (godot/godot#79914) where `screen_texture`/`hint_screen_texture` produces visible pink gridline artifacts specifically under the **Compatibility renderer** — the exact renderer both documents recommend for low-end Android. This doesn't occur on Forward+/Mobile. **Action:** prototype the palette shader on the Compatibility renderer early (Milestone 1). If the artifact reproduces, fall back to either (a) the Mobile renderer (still much lighter than Forward+, broad Android device support since Vulkan/GLES3 is now near-ubiquitous) or (b) apply the palette remap as a per-material shader on sprites/tiles instead of a screen-space post-process (loses some "free" effects like screen-wide fades cycling through the 4-color ramp, but avoids the bug entirely). |
| 2 | "Game Boy aesthetic requires 12,288 bytes of CHR RAM... 768 individual 8x8 tiles... partitioned 256/256/256 between sprites/background/shared" (Doc B, early in the rendering section) | B | This figure describes **Game Boy *Color*** total VRAM tile capacity (2 banks × 384 tiles = 768 tiles, 12,288 bytes) — not the base DMG Game Boy. The *same document*, two paragraphs later, correctly states the DMG can only have **384 tiles active at once** ($8000-$97FF = 6,144 bytes), which contradicts the 768/12,288 figure given earlier. Additionally, "CHR RAM" is **NES/Famicom terminology** (PPU pattern tables), not standard Game Boy terminology — the Game Boy's tile data simply lives in VRAM. This looks like the model blended NES, DMG, and CGB specs into one paragraph. **Practical impact is low** either way — see §6 on resolution/palette targets — but don't treat the specific byte/tile-count figures in Doc B as authoritative without checking Pan Docs directly. |
| 3 | "Godot's export pipeline natively targets... iOS (via Apple StoreKit 2 integrations)" (Doc A) | A | StoreKit 2 support for Godot comes from **third-party plugins** (e.g., `godot-store-kit`, `GodotApplePlugins`), not a built-in engine feature. More importantly: **iOS is not in this project's target platform list** (macOS, Windows, Android per the brief). Doc A spends real estate on iOS/StoreKit that isn't relevant scope — flagged so it doesn't quietly creep into the plan. |
| 4 | "Because rcedit is inherently a Windows executable... the developer must install Wine... configure Godot's Editor Settings to point directly to the rcedit executable path" for Windows export icon embedding (Doc B) | B | This was true for Godot ≤4.4. **As of Godot 4.5, the rcedit/Wine workaround is no longer needed** — Godot embeds the icon directly. Since the project will be built on Godot 4.6, this entire Wine/rcedit setup step in Doc B can be skipped. |
| 5 | Tiled is described as "antiquated" and LDtk as definitively superior for this use case (Doc A) | A | Directionally reasonable for this project (LDtk's IntGrid + multi-room world view + actively maintained Godot importer is a strong fit for a Zelda-style overworld+dungeons game), but "antiquated" overstates it — Tiled is still actively maintained, has a larger plugin ecosystem, and some Godot users prefer it for very large tilesets. The real deciding factor is the **Godot importer ecosystem**, where LDtk's `heygleeson` importer is currently more actively maintained and feature-complete than the comparable Tiled importers. This is a reasonable but not "definitive" call — see Confidence rating in §6. |
| 6 | Doc A's claim that Unity has "48% market share" and lists this as a reason against Unity | A | Specific market-share percentages from AI-generated reports are frequently fabricated or stale and weren't independently verifiable from primary sources. **It doesn't matter** — none of the *substantive* reasons to avoid Unity for this project (3D-simulated 2D pipeline, runtime fee history/licensing volatility, much larger editor footprint) depend on this statistic, so the conclusion is unaffected. Treat the number itself as decorative, not load-bearing. |
| 7 | Doc B's claim that a base 160x144 internal resolution should be "retained" and is "paramount" while Doc A recommends a 16:9-friendly resolution like a multiple of 160x144 instead | A vs B (internal conflict) | The two source documents actually **disagree with each other** here, and neither flags it. Doc A recommends a wider base resolution (e.g., 256x144 or similar 16:9-ish multiple of the GB grid) for modern screens; Doc B insists on the literal 160x144. **This is a real open decision — see §8 and the Gameplan.** Recommendation: treat 160x144 (or a clean multiple, e.g., 320x288) as *inspiration*, not a hard constraint, given the brief explicitly says "Gameboy-like... grid-based... technically realistic," not "authentic GB hardware emulation." |

---

## 5. Claims That Are Unsupported, Outdated, Overstated, or Wrong

| # | Claim | Source | Issue |
|---|---|---|---|
| 1 | The Windows export Wine/rcedit procedure (full step-by-step) | B | **Outdated** for Godot 4.5+. Do not implement this — see §4.4. |
| 2 | "12,288 bytes of CHR RAM... 768 individual 8x8 tiles" as a base Game Boy spec | B | **Incorrect/conflated** — this is the CGB two-bank total, mislabeled with NES terminology, and contradicts the document's own later (correct) statement of 384 active tiles. See §4.2. |
| 3 | Implicit framing throughout Doc B that the project should target **authentic, hardware-accurate Game Boy DMG constraints** (160x144, 4 literal colors, 4-channel audio with channel-stealing simulation, 10-sprite scanline limit enforcement, etc.) as load-bearing requirements | B | **Overstated relative to the brief.** The project brief says "Gameboy-like... feel retro... technically realistic," which is a *visual/tonal* target, not a hardware emulation target. Building a literal channel-stealing audio manager or simulating the 10-sprite flicker bug is **scope creep with no gameplay payoff** for a solo dev. These should be treated as optional flavor, not architecture requirements. |
| 4 | The overall gameplay scope implied by Doc B's "Synthesis" section — Lufia II-style visible synchronized overworld enemies + Golden Sun-style elemental Psynergy traversal puzzles + Ikari/Djinn-style risk-reward combat resource systems + a 100-floor "Ancient Cave" roguelike postgame, presented as a unified design target | B | **Massively overstated for an MVP / first playable.** Each of these systems individually is a multi-week-to-multi-month undertaking even with AI-assisted coding (because each requires its own data model, UI, balancing pass, and content). Presented together with no sequencing or scope guidance, this reads like a AAA pitch document, not a solo-dev plan. The Gameplan in this audit deliberately **sequences** these as MVP → Stretch Goal 1 → Stretch Goal 2, etc. |
| 5 | "TilePix" as a recommended tilemap tool for "developers specifically focused on tilemap creation natively on Apple hardware" (Doc A) | A | Could not be independently verified as an actively maintained, relevant tool during this audit (low-traffic itch.io listing, iPad-focused). **Low priority — not recommended.** Pixelorama and the LDtk editor (cross-platform desktop app) already cover this project's tilemap needs on a Mac Mini. |
| 6 | Doc A's claim that Godot's editor is "approximately 120 MB" vs Unity's "15 GB installation" presented as precise figures | A | Directionally true (Godot's editor download is in the 80-150MB range depending on platform/version, vs Unity Hub + Editor + modules routinely exceeding several GB), but presented with false precision. Doesn't change the conclusion — Godot is dramatically lighter — but don't repeat "120MB" as a hard fact. |

---

## 6. Recommended Toolchain

| Category | Recommendation | Confidence | Rationale |
|---|---|---|---|
| **Engine** | **Godot 4.6.x** (GDScript) | **High** | Free/MIT, native 2D pipeline, native Apple Silicon, exports to macOS/Windows/Android without royalties, huge tutorial/AI-training corpus (important for AI-assisted dev — GDScript is well-represented in LLM training data). Both source docs and independent verification agree. |
| **Renderer** | **Mobile** renderer (not Forward+, not Compatibility) | **Medium** | Forward+ is desktop-only and overkill for 2D. Compatibility has the known `SCREEN_TEXTURE` artifact (§4.1) and is the most behind on features. Mobile renderer supports the screen-reading palette shader cleanly, runs on Vulkan/Metal/D3D12, and modern Android devices (last ~6 years) support it fine. If you encounter low-end Android devices that can't run Mobile, fall back to Compatibility + per-sprite palette shaders. |
| **Level editor** | **LDtk + heygleeson/godot-ldtk-importer** | **High** | Multi-room world view is a near-perfect fit for a Zelda-style overworld+dungeons game; IntGrid cleanly separates collision/logic from visuals; importer is actively maintained and supports post-import scripts for auto-generating collision/physics layers. |
| **Pixel art** | **Aseprite** (primary) + **Pixelorama** (free fallback / secondary) | **High** | Aseprite ($20 one-time) has the best animation/sprite-sheet workflow and is the genre standard — worth the cost for a multi-year solo project. Pixelorama is a completely free, Godot-native alternative if you'd rather not pay, and its tilemap tooling integrates well conceptually with the Godot/LDtk pipeline. Pixen is a fine native-Mac alternative if you specifically want deep macOS integration (Sidecar/iPad), but has a smaller community than Aseprite/Pixelorama. |
| **Audio** | **Furnace Tracker** | **High** | Free, open source, accurate Game Boy DMG emulation, active community, exports to standard formats (.wav/.ogg via render). DefleMask is the only real alternative and it's paid with no functional advantage for this scope. |
| **Target platforms** | **macOS, Windows, Android** (as specified) — treat iOS as a *possible future* export, not in scope now | **High** | Matches the brief. Godot supports all three without licensing fees. Android requires the most setup work (OpenJDK 17, SDK, keystore) — budget time for this in early milestones, not at the end. |
| **Resolution/aesthetic target** | **"Gameboy-like, modern retro"** — pick a clean low resolution that's a multiple of an 8x8 or 16x16 grid and reasonably close to 16:9 (e.g., **256x224** or **320x180**), nearest-neighbor filtering, integer scaling, viewport stretch mode, 4-to-8 color palette via shader or authored assets | **Medium** | This is explicitly an **open decision** (see §4.7) — the two source docs disagree, and the project brief leaves room. "Inspired by," not "constrained to," GB hardware. A slightly wider-than-GB resolution avoids ugly pillarboxing on modern phones/monitors while keeping the chunky-pixel feel. Final number should be picked once you've drawn a few test sprites and seen how they read at different scales. |

---

## 7. Rejected Alternatives and Why

| Alternative | Category | Why rejected |
|---|---|---|
| **Unity** | Engine | 2D is simulated in a 3D pipeline; licensing has been volatile (runtime-fee controversy); editor footprint is huge. No advantage for a 2D-only retro RPG. |
| **Unreal Engine** | Engine | Built for 3D AAA; 2D support (Paper2D) is a secondary feature; massive overkill and a worse fit for GDScript-style AI-assisted iteration. |
| **GameMaker** | Engine | Fast for arcade-style 2D, but its event/room model creates friction for the kind of deeply interconnected data systems (party stats, inventory, turn queues) this project needs. Also has licensing costs. |
| **Defold** | Engine | Lighter weight and faster to compile than Godot, but smaller community, ECS architecture is a bigger conceptual jump, and its UI tooling is weaker for the menu-heavy turn-based combat/inventory screens this project needs. Godot's advantages here outweigh Defold's binary-size edge for a desktop/Android target. |
| **GB Studio** | Engine | Purpose-built for *authentic* Game Boy ROMs; outputs ROM/Web only with no native Android/Windows/macOS export and no native touch UI. Wrong tool for "Gameboy-*like*, cross-platform." Confirmed via current GB Studio docs. |
| **Tiled** | Level editor | Still viable and actively maintained, but LDtk's multi-room world view and IntGrid model are a better conceptual match for Zelda-style interconnected rooms, and its current Godot importer ecosystem is more actively maintained than comparable Tiled importers. Not "antiquated," just a worse fit here. |
| **Godot built-in TileMapLayer only (no external editor)** | Level editor | Viable for a *very* small game, but for an overworld + multiple dungeons, an external editor with a world map view (LDtk) will save significant time over scrolling/zooming in the Godot 2D editor. |
| **DefleMask** | Audio | Paid, no functional advantage over Furnace for GB DMG composition; Furnace is the actively-developed free alternative. |
| **Authentic hardware-constraint simulation** (literal 160x144, literal 4-channel audio with channel-stealing, literal 10-sprite-per-line flicker) | Aesthetic/architecture | High implementation cost, no gameplay benefit, and not requested by the brief ("Gameboy-*like*... technically realistic" ≠ "hardware-accurate emulation"). Treat as optional flavor only if time allows late in development. |

---

## 8. Open Decisions — RESOLVED (2026-06-11)

All five were resolved in a follow-up conversation. Recorded here for the historical record; the Gameplan reflects the resolutions directly.

1. **Base resolution/palette — RESOLVED: GBA-like, not GBC-like.** Kayden isn't attached to a literal Game Boy look and prefers a GBA-style aesthetic. Decision: **240x160 base resolution** (GBA's native 3:2 res), nearest-neighbor filtering, integer scaling, viewport stretch. Palette is **not** artificially restricted to 4 colors — GBA-era games used 15-bit color (32,768), so author sprites/tiles with whatever palette looks good and let the art establish the retro feel, rather than enforcing a hard color-count limit. This also resolves the Doc A vs Doc B resolution disagreement (§4.7) in favor of "wider, GBA-like" over "literal 160x144."
2. **Renderer/palette-shader fallback — RESOLVED: drop the global palette-swap shader from MVP entirely.** Since the game isn't targeting a fixed 4-color palette (see #1 above), the `SCREEN_TEXTURE`-based palette-swap post-process (the thing that risked the Compatibility-renderer bug, audit §4.1) is no longer needed for the core look. **Mobile renderer, no `SCREEN_TEXTURE` dependency in MVP** — sidesteps godot/godot#79914 entirely. A CRT/scanline/color-grading shader remains a possible cosmetic Stretch Goal, built and tested per-platform with a settings toggle so it can be disabled if it misbehaves on any device.
3. **Aseprite vs Pixelorama vs Pixen — RESOLVED: Aseprite primary.** Since Claude/Codex are doing most of the asset-pipeline work, the deciding factor is automation: Aseprite has a Lua scripting API and a CLI (`aseprite --batch script.lua`) that an AI agent can invoke directly to slice sprite sheets, batch-export layers/animations, and regenerate assets after edits — Pixelorama and Pixen are GUI-only with no equivalent automation surface. The $20 one-time cost is trivial against the time saved by scriptable exports. Pixelorama remains a fine zero-cost fallback if Aseprite is ever unavailable, but Aseprite is the default. See the pros/cons table below.
4. **Audio authenticity — RESOLVED: compose in Furnace for the *sound*, skip the literal hardware-engine architecture.** Use Furnace Tracker (free, GB/GBA-capable chip emulation) to compose music/SFX that *sound* chiptune, export to `.ogg`, and play them through a simple `AudioStreamPlayer`/`AudioStreamPlayer2D` setup (already in Gameplan §13). The "literal 4-channel hardware engine with channel-stealing for SFX" (Doc B) is **dropped from Stretch Goals entirely** — it was always pure internal-architecture authenticity with no player-facing benefit, and is even less relevant now that the project isn't targeting literal GB hardware constraints (see #1).
5. **Scope sequencing for big design-doc systems — RESOLVED: accept the Gameplan's proposed order** (equipment → elemental counters → telegraphed combat UI → traversal abilities → Djinn/Ikari-style resources → more content → roguelike postgame), per Gameplan §17. No changes requested.

### 8.1 Art tool pros/cons (decision #3 detail)

| Tool | Pros | Cons | Verdict |
|---|---|---|---|
| **Aseprite** | Lua scripting API + CLI batch mode (`aseprite -b`) — Claude/Codex can script sprite-sheet slicing, animation export, and palette changes without a human at the GUI; industry-standard `.aseprite` format with first-class animation/onion-skin tools; $20 one-time. | Closed source; small one-time cost. | **Primary.** The automation surface is decisive for an AI-assisted workflow. |
| **Pixelorama** | Free, open source (MIT), built in Godot so its file/project model feels familiar; built-in tilemap and pixel-scaling algorithms (cleanEdge, OmniScale). | GUI-only — no CLI/scripting hook for agents to drive exports; less mature animation/export tooling than Aseprite. | **Fallback.** Use if Aseprite is unavailable or for quick one-off edits; not the primary pipeline tool. |
| **Pixen** | Native Mac app, actively maintained (Pixen 6), nice Sidecar/iPad workflow if drawing by hand. | Mac-only; no scripting/CLI automation; smaller community/less AI-training-data coverage for troubleshooting. | **Not recommended** for this project — automation matters more than native-Mac polish here. |

---

## 9. Sources Used for Verification

- [Godot 4.6 Release: It's all about your flow](https://godotengine.org/releases/4.6/)
- [Maintenance release: Godot 4.6.3 — Godot Engine](https://godotengine.org/article/maintenance-release-godot-4-6-2/)
- [Multiple resolutions — Godot Engine (stable) docs](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- [AStarGrid2D — Godot Engine (stable) docs](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html)
- [Screen-reading shaders — Godot Engine (stable) docs](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
- [Glitch in shader when using screen_texture and Compatibility mode — godot/godot#79914](https://github.com/godotengine/godot/issues/79914)
- [Renderers — Godot Engine (4.4) docs](https://docs.godotengine.org/en/4.4/tutorials/rendering/renderers.html)
- [Pixelorama — GitHub (Orama-Interactive)](https://github.com/Orama-Interactive/Pixelorama)
- [Pixelorama — Godot Engine showcase](https://godotengine.org/showcase/pixelorama/)
- [godot-ldtk-importer — GitHub (heygleeson)](https://github.com/heygleeson/godot-ldtk-importer)
- [Auto layers — LDtk docs](https://ldtk.io/docs/general/auto-layers/)
- [IntGrid layers — LDtk docs](https://ldtk.io/docs/general/intgrid-layers/)
- [Furnace — multi-system chiptune tracker — GitHub (tildearrow)](https://github.com/tildearrow/furnace)
- [DefleMask — official site](https://www.deflemask.com/)
- [Pixen — pixel art editor for Mac](https://pixenapp.com/)
- [Tile Data — Pan Docs](https://gbdev.io/pandocs/Tile_Data.html)
- [OAM — Pan Docs](https://gbdev.io/pandocs/OAM.html)
- [GB Studio 4.3.0 devlog — Chris Maltby](https://chrismaltby.itch.io/gb-studio/devlog/1547703/gb-studio-430-now-available)
- [GB Studio Settings docs](https://www.gbstudio.dev/docs/settings/)
- [Exporting for Android — Godot Engine (stable) docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [Exporting for macOS — Godot Engine (latest) docs](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_macos.html)
- [Changing application icon for Windows — Godot Engine (stable) docs](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html)
- [Wine and rcedit not working for mac — Godot Forum (4.5+ rcedit no longer needed)](https://forum.godotengine.org/t/wine-and-rcedit-not-working-for-mac-to-export-for-windows/74442)
- [Exporting for iOS — Godot Engine (stable) docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)

---

## 10. Final Recommendation Summary

| Decision | Final Recommendation | Confidence |
|---|---|---|
| **Engine** | Godot 4.6.x, GDScript, Mobile renderer, no `SCREEN_TEXTURE` palette shader in MVP | High |
| **Level editor** | LDtk + heygleeson/godot-ldtk-importer | High |
| **Pixel art workflow** | Aseprite (primary, scriptable via Lua/CLI for AI-driven pipelines), Pixelorama as free fallback | High |
| **Audio workflow** | Furnace Tracker, exported to .ogg, simple AudioStreamPlayer manager (no literal hardware-channel emulation) | High |
| **Target platforms** | macOS, Windows, Android (desktop-first dev, Android validated early) | High |
| **Aesthetic target** | **GBA-like, not GBC-like**: 240x160 base resolution, nearest-neighbor filtering, integer scaling, viewport stretch, unrestricted palette (no forced 4-color limit) | High (resolved 2026-06-11) |
