class_name CombatStats
extends Resource
## The one shared combat stat block (T-052, Kayden's 2026-07-07 direction):
## characters and enemies use the SAME stats so abilities can target either
## side without parallel systems. Deliberately small and custom - not D&D's
## six scores. Scale: 0 = can't use the stat, 1-2 weak, 3-4 average, 5-6
## strong, 7-8 exceptional, 9-10 boss/late-game. Level-1 units mostly sit
## in 2-6.
##
## Keep this boring: no UI, animation, inventory, AI, save, or turn logic.
## Templates only - current HP and other runtime state live on GameState /
## combat units, never here.

@export_range(1, 999) var max_hp: int = 10
## MP pool for AbilityData.mp_cost (T-035) - our addition to the shared
## block; the adopted spec left the resource pool undecided.
@export_range(0, 99) var max_mp: int = 0

## Physical damage, shoving, heavy weapons.
@export_range(0, 99) var might: int = 1
## Damage reduction, blocking, resisting physical pressure.
@export_range(0, 99) var guard: int = 0
## Accuracy, crits, ranged and finesse attacks.
@export_range(0, 99) var skill: int = 1
## Initiative, evasion, movement feel.
@export_range(0, 99) var speed: int = 1
## Magic power, status effects, mental resistance.
@export_range(0, 99) var focus: int = 0

## Tiles the unit can move in combat (consumed by Phase 4's combat grid).
@export_range(1, 20) var move_range: int = 3
