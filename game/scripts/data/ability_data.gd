class_name AbilityData
extends Resource
## Ability record (T-035; see /BLUEPRINT.md -> Data Model). Consumed by the
## Phase 4 combat command menu; balance numbers live in .tres instances under
## game/data/abilities/, never in scene scripts (locked decision).

enum TargetType { ENEMY, ALLY, SELF }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var mp_cost: int = 0
@export var target_type: TargetType = TargetType.ENEMY
## Added to the user's attack for damage (ENEMY) or used as the heal amount
## (ALLY/SELF). The d10 hit roll applies to ENEMY abilities only.
@export var power: int = 0
## Manhattan range in arena cells; 1 = melee reach (the T-063 range-field
## decision: abilities carry their own reach, stats carry move_range and the
## basic attack_range).
@export var attack_range: int = 1
## Stretch fields (S-002 elements, S-004 overworld traversal) - present so
## the schema doesn't churn, consumed by nothing at MVP.
@export var element: String = ""
@export var overworld_use := false
## S-011/TK-003 (D-031): when non-empty, using this ability routes through
## the shared reaction seam (ReactionCaster -> room preview/commit) with this
## verb instead of bespoke effect code. Must be one of ReactionCore.VERBS.
@export var reaction_verb: String = ""
