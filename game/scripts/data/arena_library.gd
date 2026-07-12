class_name ArenaLibrary
extends RefCounted
## The authored D-018 arena catalog. It is a normal helper, not another
## autoload: SceneManager remains the project's single global owner.

const RECORD_PATHS := [
	"res://data/arenas/forest_open_glade.tres",
	"res://data/arenas/forest_sunlit_meadow.tres",
	"res://data/arenas/forest_split_grove.tres",
	"res://data/arenas/forest_winding_copse.tres",
	"res://data/arenas/forest_crossroads.tres",
	"res://data/arenas/forest_thorn_choke.tres",
	"res://data/arenas/forest_old_growth_maze.tres",
	"res://data/arenas/dungeon_stone_hall.tres",
]

static var _registry: ArenaRegistry


static func registry() -> ArenaRegistry:
	if _registry != null:
		return _registry
	_registry = ArenaRegistry.new()
	for path in RECORD_PATHS:
		var record := load(path) as ArenaData
		if record == null:
			push_error("ArenaLibrary: could not load authored arena %s" % path)
			continue
		if not _registry.register(record):
			push_error("ArenaLibrary: %s" % _registry.last_error)
	return _registry


## Test-only reset for a clean resource registry after a fixture mutates one.
static func clear_cache() -> void:
	_registry = null
