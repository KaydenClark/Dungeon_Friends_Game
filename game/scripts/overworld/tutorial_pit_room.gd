class_name TutorialPitRoom
extends LdtkRoom
## Tutorial dungeon Room 3 - the pit room (T-027, reworked per Kayden's
## 2026-07-07 notes: "just focus on pushing blocks and the jumping over the
## ledges"). From the south: two 1-cell ledges teach the jump (each exactly
## the jumpable width), then a 2-cell chasm - beyond the 1-cell jump limit -
## teaches block-fills-pit: push the block in, cross on the filled cell,
## jump the last gap. Wedge-proof by construction: the block sits on the
## chasm's near bank, every column it can be pushed into sinks it usefully,
## and the ledges can't be reached by a push. Leaving south still resets the
## room (freed + rebuilt) as a belt-and-braces escape valve.
##
## Doorway targets: hub_return (south), fight_room (north, past the chasm).


func _init() -> void:
	level_path = "res://assets/levels/tutorial_dungeon.ldtk"
	level_name = "PitRoom"


func _room_ready() -> void:
	if not SceneManager.flags.get("pit_room_seen", false):
		SceneManager.flags["pit_room_seen"] = true
		SceneManager.show_dialogue([
			"Narrow ledges split the floor ahead -",
			"a single square wide. A running leap might do it.",
			"(Space or C jumps the gap you're facing.)",
		])
	player.move_finished.connect(_chasm_hint)


## One-time hint when the player first reaches the chasm's near bank: the
## 2-wide gap is deliberately unjumpable and the block is the answer.
func _chasm_hint() -> void:
	if SceneManager.flags.get("chasm_hint_seen", false):
		return
	if player.cell.y > 6:
		return
	SceneManager.flags["chasm_hint_seen"] = true
	SceneManager.show_dialogue([
		"This chasm is far too wide to jump...",
		"but that block looks heavy enough to fall.",
		"(Walk into the block to push it.)",
	])


func _on_doorway(fields: Dictionary) -> void:
	match str(fields.get("TargetRoom", "")):
		"hub_return":
			SceneManager.exit_room()
		"fight_room":
			var fight := TutorialFightRoom.new()
			fight.rooms_below_to_hub = 2
			SceneManager.enter_room(fight)
