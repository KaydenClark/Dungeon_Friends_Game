class_name MapRegistry
extends Object
## The one place that knows which stable map id builds which room (T-038).
## SaveData.current_map stores these ids; the load flow (T-040), restart/boot
## (main.gd), and the dev warp menu (T-049) all resolve rooms through here
## instead of hardcoding constructors at each call site. Registering a new
## room = one _entries() row; the warp menu and save format pick it up for free.

## Stable-ordered registry. `type` is the room's script class - used both to
## construct (build) and to recognize a live instance (id_for). A function,
## not a const: class references aren't constant expressions in GDScript.
static func _entries() -> Array[Dictionary]:
	return [
		{"id": "forest", "label": "Forest", "type": ForestRoom},
		{"id": "withered_grove", "label": "Withered Grove", "type": GroveRoom},
		{"id": "tutorial_hub", "label": "Tutorial Hub", "type": TutorialHubRoom},
		{"id": "tutorial_chest", "label": "Chest Room", "type": TutorialChestRoom},
		{"id": "tutorial_pit", "label": "Pit Room", "type": TutorialPitRoom},
		{"id": "tutorial_fight", "label": "Fight Room", "type": TutorialFightRoom},
	]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for e in _entries():
		out.append(e.id)
	return out


## Fresh room instance for a map id, or null (with a warning) for an unknown
## id - a hand-edited save must not crash the boot.
static func build(id: String) -> Node2D:
	for e in _entries():
		if e.id == id:
			return e.type.new()
	push_warning("MapRegistry: unknown map id '%s'" % id)
	return null


## The stable id for a live room instance ("" when the node is not a
## registered room). Matches by exact script, not `is`, so a hypothetical
## subclass never masquerades as its parent room in a save file.
static func id_for(room: Node2D) -> String:
	if room == null:
		return ""
	for e in _entries():
		if room.get_script() == e.type:
			return e.id
	return ""


static func label(id: String) -> String:
	for e in _entries():
		if e.id == id:
			return e.label
	return ""
