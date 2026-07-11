extends Node
## Dev tool: boot each room in a real (windowed) run and save one PNG per
## room - the quick demo artifact the AGENTS.md proof contract asks for.
## Not part of the game; needs a display (screenshots are black under
## --headless's dummy renderer).
##
## Run: Godot --path . scenes/dev/screenshot_tour.tscn [-- --out=/abs/dir]
## Writes forest.png, hub.png, pit.png, fight.png, chest.png and quits.

var out_dir := "user://screenshots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	# Never let a real player save cover the tour with the boot prompt.
	_clear_tour_saves()
	SceneManager.save_dir = "user://saves_screenshot_tour"
	# Skip the one-time room intros so dialogue boxes don't cover the shots.
	for flag in ["hub_seen", "pit_room_seen", "plate_hint_seen",
			"fight_room_seen", "chest_room_seen"]:
		SceneManager.flags[flag] = true
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(20)
	await _shot("forest")
	for room in [["hub", TutorialHubRoom], ["pit", TutorialPitRoom],
			["fight", TutorialFightRoom], ["chest", TutorialChestRoom]]:
		_warp(room[1].new())
		await _frames(20)
		await _shot(room[0])
	_clear_tour_saves()
	SceneManager.save_dir = SaveManager.DEFAULT_DIR
	print("SCREENSHOT TOUR: done -> ", out_dir)
	get_tree().quit(0)


func _clear_tour_saves() -> void:
	var root := DirAccess.open("user://")
	if root == null or not root.dir_exists("saves_screenshot_tour"):
		return
	var saves := DirAccess.open("user://saves_screenshot_tour")
	if saves != null:
		for f in saves.get_files():
			saves.remove(f)
	root.remove("saves_screenshot_tour")


## Same teardown the DebugOverlay warps use: boot the room with no stack.
func _warp(room: Node2D) -> void:
	for r in SceneManager.room_stack:
		r.queue_free()
	SceneManager.room_stack.clear()
	if SceneManager.current_room:
		SceneManager.current_room.queue_free()
		SceneManager.current_room = null
	SceneManager.boot_room(room)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("  wrote ", path)
