# Agent Instructions — Dungeon Friends

This file is the canonical reference for any AI agent (Claude, Codex, or other) working in this repo. Read this before making changes. For the full design/architecture rationale, read `docs/planning/Gameplan.md` and `docs/research/audited_research.md` — this file is a quick-reference summary, those are the source of truth for *why*.

## Project summary

A GBA-like (not GBC-like) 2D top-down adventure RPG: grid-based overworld + dungeons (Zelda-style puzzles: pushable blocks, switches, locked doors), turn-based party combat, recruitable party members. Built in Godot 4.6.x / GDScript, targeting macOS, Windows, and Android. Solo developer (Kayden), heavily AI-assisted.

## Repo layout

- `/game` — the Godot project. `game/project.godot` is the project root. Open this in Godot 4.6+.
- `/docs` — planning and research docs. Start with `docs/planning/Gameplan.md`.
- `/AGENTS.md`, `/CLAUDE.md` — this file and its Claude-specific pointer.

Inside `/game`:

```
game/
├── addons/ldtk-importer/   # heygleeson's LDtk importer (do not hand-edit)
├── assets/
│   ├── art/                # Aseprite source files, exported sprite sheets, _scripts/ for batch export
│   ├── audio/               # Furnace exports (.ogg)
│   └── levels/world.ldtk    # single LDtk project, all levels
├── data/                     # .tres Resource instances (characters/, enemies/, items/, abilities/, encounters/)
├── scenes/                   # .tscn files
├── scripts/                  # .gd files, mirrors scenes/ + data class defs in scripts/data/
└── shaders/
```

## Locked technical decisions (do not relitigate without flagging to Kayden)

- **Engine/renderer**: Godot 4.6.x, GDScript, **Mobile** renderer.
- **Resolution**: **240x160** base resolution (GBA-like, 3:2), nearest-neighbor filtering, integer scaling, viewport stretch mode, `keep` aspect.
- **Palette**: unrestricted — do not add a global 4-color palette shader or `SCREEN_TEXTURE` post-process. (This was deliberately removed; see audit §4.1 and §8 decision #2.)
- **Tilemaps**: use `TileMapLayer`, never the deprecated `TileMap` node.
- **Pathfinding**: `AStarGrid2D` with `diagonal_mode = DIAGONAL_MODE_NEVER`, Manhattan heuristic.
- **Movement**: grid-snapped via `Tween`, never raw `velocity`-based free movement.
- **Data**: all stats/items/abilities are `Resource` (`.tres`) subclasses defined in `scripts/data/`. Never hardcode balance numbers in scene scripts.
- **Architecture**: single Autoload (`SceneManager`). No other autoloads — additional global state goes on `SceneManager`'s `GameState`/`SaveData` resource, not new singletons.
- **Combat**: two-layer FSM (Battle FSM + per-entity FSM) + `TurnManager`, ordered by `speed` stat.
- **Audio**: Furnace Tracker → `.ogg` → simple `AudioStreamPlayer`/`AudioStreamPlayer2D`. No literal hardware-channel-emulation engine — that idea was deliberately dropped, not deferred.
- **Art tool**: Aseprite primary (Lua/CLI scriptable — scripts live in `game/assets/art/_scripts/`). Pixelorama is an acceptable free fallback for one-off edits.
- **Enemies**: visible on the overworld map, synchronized-turn movement (move when player moves), trigger combat on contact. No random/invisible encounters.

## MVP vs. Stretch

Before adding *any* new system (equipment, elemental damage, traversal abilities, resource gauges, roguelike mode, etc.), check `docs/planning/Gameplan.md` §16 (MVP Scope) and §17 (Stretch Goals, sequenced). If a request would add something from §17 out of order, flag it to Kayden rather than just building it — the sequencing exists to manage scope on a solo project.

## Conventions

- Milestones are sized to 2-3 hour chunks (Gameplan §15) — when picking up work, prefer completing one milestone cleanly over partially starting several.
- Commit messages: describe what changed and why, referencing the Gameplan section/milestone where relevant (e.g., "M2.1: implement PushableBlock + PressurePlate").
- Don't commit Android keystores (`.jks`/`.keystore`) or signing passwords. See `.gitignore`.

## Running the project

Open `game/project.godot` in the Godot 4.6+ editor and press F5 (or run a specific scene with F6). There is no separate build step for development — exports (macOS/Windows/Android) are configured via the Godot editor's Export dialog per `docs/planning/Gameplan.md` §14.
