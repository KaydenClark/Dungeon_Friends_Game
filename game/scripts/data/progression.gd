class_name Progression
## Pure progression math (T-045, M3.1). Phase 3 pins the *data shape* only:
## party_levels/party_xp live on GameState (T-036) and SaveData carries them
## from day one, so Phase 5's level-up mechanics (stat growth, combat
## integration - M5.3, do not build early) land without a save-schema bump.
##
## PLACEHOLDER NUMBERS: the base cost and quadratic shape below are a first
## guess for tests to pin, not tuning. Rebalance freely at Phase 5 - the
## contract the tests hold is only: known level-1 base, strictly rising
## cost, strictly rising per-level deltas, out-of-range levels clamp.

## XP required to go from `level` to `level + 1`. Quadratic placeholder:
## 10, 40, 90, 160, ... (10 * level^2).
static func xp_to_next(level: int) -> int:
	var l := maxi(level, 1)
	return 10 * l * l
