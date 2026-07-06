# Dungeon Friends

> Generated from LLM Workbench v2.1. See `RUNBOOK.md` -> Upgrading The
> Harness.

A retro-pixel-art-inspired 2D top-down Zelda-style adventure game where you
recruit a team and fight through turn-based combat across dungeons and the
overworld, rendered natively at flexible HD/ultrawide resolutions rather than
a locked handheld-style canvas.

A solo, AI-assisted Godot 4.6 project: grid-based overworld and dungeon
exploration (Zelda-style block/switch/key puzzles), Baldur's-Gate/Fire-Emblem-
inspired turn-based party combat, and recruitable "Dungeon Friends" party
members. The world starts in a fantasy forest and later expands into a castle
city, mountains, and rivers. Current state: a first-playable walking
skeleton exists on placeholder art - walk a forest test room, talk to an
NPC, bump a visible enemy into a turn-based d10 battle, win a key, and open
a locked path. Real art, LDtk-authored maps, and the full combat system are
next.

## How This Project Is Run

This repository is governed by a small set of control documents. Read them
before changing anything:

- [`AGENTS.md`](AGENTS.md) - how agents behave here: authority order,
  read/edit scope, the task-selection loop, documentation ownership, and
  proof rules.
- [`BLUEPRINT.md`](BLUEPRINT.md) - what this project is: vision, architecture,
  invariants, and preserved decisions. Stable and source-backed.
- [`TASKBOARD.md`](TASKBOARD.md) - the live work queue and append-only proof
  log. Its **Executive Brief** (top of the file) is the one-glance status for
  anyone who doesn't want to read code.
- [`RUNBOOK.md`](RUNBOOK.md) - how to set up, run, test, build/export, and
  recover this project, plus the verification commands that gate "done".

- [`HARNESS_FEEDBACK.md`](HARNESS_FEEDBACK.md) - the return channel to the
  reusable harness these docs came from.

For the full game-design and architecture rationale, see
[`docs/planning/Gameplan.md`](docs/planning/Gameplan.md) and
[`docs/research/audited_research.md`](docs/research/audited_research.md) -
`BLUEPRINT.md` is the dense summary; those are the "why."

This project was originally adopted into the LLM Workbench harness from an
existing set of planning docs (not bootstrapped from a blank prompt) - see
`docs/LEGACY_HARNESS.md` for the pre-harness `AGENTS.md`/`CLAUDE.md` this
was migrated from.

## Getting Started

```bash
git clone https://github.com/KaydenClark/Dungeon_Friends_Game.git   # install
/Applications/Godot.app/Contents/MacOS/Godot --path game            # run
cd game && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import   # test
```

Full setup, environment, and troubleshooting steps live in
[`RUNBOOK.md`](RUNBOOK.md).

## Working With Agents

The control docs are intentionally plain Markdown so they work with Codex,
Claude, or any other agent that reads repository instructions - no framework
or preprocessing required.

For **Claude Code**, `CLAUDE.md` contains `@AGENTS.md` so the rules load
automatically. Other agents should be pointed at `AGENTS.md` as their entry
point.

Every completed agent task leaves proof in its final response and in the
`TASKBOARD.md` proof log. Milestone tasks additionally require a short demo
artifact (screenshot, recording, or one-command demo) so work is accepted on
product truth, not passing checks alone.

## Project Status

See the **Executive Brief** at the top of [`TASKBOARD.md`](TASKBOARD.md) for
the current shipping state, health, any decision the owner needs to make,
blockers, and the next milestone.

## License

No license chosen yet - all rights reserved by default. Add a `LICENSE` file
when Kayden decides on one.
