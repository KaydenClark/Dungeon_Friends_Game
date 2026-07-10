class_name CombatMath
extends Object
## The real d10 percentage combat math (T-060; locked Core Logic rule: roll
## 1-10 against a stat-derived threshold, thresholds read as clean
## percentages). Pure statics shared by CombatScene and the unit tests -
## test-the-real-path, one implementation. Numbers are first-cut tunables
## for Kayden's T-069 playtest; the *shape* (clamped band, roll-high-good,
## min-1 damage) is the contract.


## Percent-to-hit tier (the tens digit shown to the player): 5 + attack
## - defense, minus 2 when the defender is bracing, clamped to a 10%..90%
## band so nothing is ever a guaranteed hit or a certain miss.
static func hit_threshold(attack: int, defense: int, defending: bool) -> int:
	return clampi(5 + attack - defense - (2 if defending else 0), 1, 9)


## The d10 value the attacker must meet or beat (roll-high-good): a 70% tier
## (threshold 7) means "roll a 4 or higher".
static func needed_roll(threshold: int) -> int:
	return 11 - threshold


## Damage on a hit: attack (plus the ability's power, 0 for a basic attack)
## minus half the defender's defense (min 1), halved again (min 1) when the
## defender is bracing.
static func attack_damage(attack: int, defense: int, defending: bool,
		power: int = 0) -> int:
	var dmg := maxi(1, attack + power - int(defense / 2.0))
	if defending:
		dmg = maxi(1, int(dmg / 2.0))
	return dmg


## Healing from a support ability or item: flat power, at least 1.
static func heal_amount(power: int) -> int:
	return maxi(1, power)
