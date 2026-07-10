class_name TurnManager
extends RefCounted
## Initiative and turn sequencing (T-061; locked decision): sorts ALL
## combatants - party and enemies together - by individual speed each round
## and steps through them one at a time. Strict per-unit initiative, never a
## whole-team phase. Pure logic, no scene access, unit-tested.

var units: Array[CombatUnit] = []
var round_number := 0
var _queue: Array[CombatUnit] = []


func setup(all_units: Array[CombatUnit]) -> void:
	units = all_units
	round_number = 0
	_queue.clear()


## The initiative order for a fresh round: living units, fastest first.
## Ties break deterministically: player units act before enemies, then
## earlier setup() order wins (stable, so tests and replays agree).
func build_order() -> Array[CombatUnit]:
	var order: Array[CombatUnit] = []
	for u in units:
		if u.alive():
			order.append(u)
	# Strict-weak comparison over (speed desc, player-first, setup index asc);
	# the index term makes the sort deterministic regardless of sort stability.
	order.sort_custom(func(a: CombatUnit, b: CombatUnit) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		if a.is_player != b.is_player:
			return a.is_player
		return units.find(a) < units.find(b))
	return order


## The next living unit to act, refilling from a fresh initiative sort when
## the round runs out (speed changes and deaths mid-round are respected on
## the refill). Returns null only when no one is left alive.
func next_unit() -> CombatUnit:
	while true:
		if _queue.is_empty():
			var order := build_order()
			if order.is_empty():
				return null
			round_number += 1
			_queue = order
		var u: CombatUnit = _queue.pop_front()
		if u.alive():
			return u
	return null  # unreachable; satisfies the analyzer


func players_alive() -> bool:
	for u in units:
		if u.is_player and u.alive():
			return true
	return false


func enemies_alive() -> bool:
	for u in units:
		if not u.is_player and u.alive():
			return true
	return false


func battle_over() -> bool:
	return not players_alive() or not enemies_alive()
