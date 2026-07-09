class_name CombatUnit
extends RefCounted
## One combatant in a tactical battle (T-061/T-062): a stats snapshot plus
## live battle state. Built from CharacterStats (party) or EnemyStats (foes);
## never mutates the source Resource - combat writes back through the
## SceneManager result payload, not by editing .tres data.

## Per-entity FSM (locked two-layer decision; the Battle FSM lives in
## CombatScene): AwaitingTurn -> CheckRange -> Moving -> SelectingAction ->
## ExecutingCommand -> TakingDamage/Healing -> back, or Dead.
enum EntityState {
	AWAITING_TURN, CHECK_RANGE, MOVING, SELECTING_ACTION,
	EXECUTING_COMMAND, TAKING_DAMAGE, DEAD,
}

var unit_id := ""        # roster id for party members; "<enemy_id>_<n>" for foes
var display_name := ""
var attack := 0
var defense := 0
var speed := 0
var max_hp := 0
var hp := 0
var max_mp := 0
var mp := 0
var move_range := 3
var attack_range := 1
var abilities: Array[AbilityData] = []
var cell := Vector2i.ZERO
var is_player := false
var is_boss := false
var defending := false
var state := EntityState.AWAITING_TURN
var node: Node2D
var info: Label


func alive() -> bool:
	return hp > 0


static func from_character(id: String, stats: CharacterStats,
		cur_hp: int, cur_mp: int) -> CombatUnit:
	var u := CombatUnit.new()
	u.unit_id = id
	u.display_name = stats.display_name
	u.attack = stats.attack
	u.defense = stats.defense
	u.speed = stats.speed
	u.max_hp = stats.max_hp
	u.hp = clampi(cur_hp, 0, stats.max_hp)
	u.max_mp = stats.max_mp
	u.mp = clampi(cur_mp, 0, stats.max_mp)
	u.move_range = stats.move_range
	u.attack_range = stats.attack_range
	u.abilities = stats.starting_abilities
	u.is_player = true
	return u


static func from_enemy(stats: EnemyStats, index: int) -> CombatUnit:
	var u := CombatUnit.new()
	u.unit_id = "%s_%d" % [stats.id, index]
	u.display_name = stats.display_name
	u.attack = stats.attack
	u.defense = stats.defense
	u.speed = stats.speed
	u.max_hp = stats.max_hp
	u.hp = stats.max_hp
	u.move_range = stats.move_range
	u.attack_range = stats.attack_range
	u.abilities = stats.abilities
	u.is_boss = stats.id == "boss_slime"
	return u
