extends "res://tests/gd_test.gd"
## Unit tests for PressurePlate + PuzzleController + the plate-driven
## LockedDoor (T-024). Pins the locked momentary semantics: pressed while any
## occupant (player or block) stands on the plate's cell, released on vacate;
## a plate-driven door opens while pressed and re-locks on release - but never
## onto something standing in the doorway.


func _make_grid(w := 7, h := 7) -> RoomGrid:
	var g := RoomGrid.new()
	add_child(g)
	g.setup_grid(w, h)
	return g


func _plate(g: RoomGrid, c: Vector2i, target := "door_a") -> PressurePlate:
	var p := PressurePlate.new()
	p.room = g
	p.cell = c
	p.target_id = target
	g.add_child(p)
	p.watch_room()
	return p


func _door(g: RoomGrid, c: Vector2i, link := "door_a") -> LockedDoor:
	var d := LockedDoor.new()
	d.room = g
	d.cell = c
	d.link_id = link
	g.set_blocked(c, true)
	g.register(d, c)
	return d


func _wire(plates: Array, doors: Array, levers: Array = []) -> PuzzleController:
	var pc := PuzzleController.new()
	pc.plates = plates
	pc.doors = doors
	pc.levers = levers
	add_child(pc)
	pc.wire()
	return pc


func _lever(g: RoomGrid, c: Vector2i, target := "door_a") -> Lever:
	var lever := Lever.new()
	lever.room = g
	lever.cell = c
	lever.target_id = target
	g.register(lever, c)
	return lever


func test_player_press_and_release() -> void:
	var g := _make_grid()
	var plate := _plate(g, Vector2i(3, 3))
	var p := Player.new()
	g.register(p, Vector2i(3, 4))
	not_ok(plate.pressed, "plate starts released")
	p.try_step(Vector2i.UP)   # onto the plate
	ok(plate.pressed, "player standing on the plate presses it")
	p.moving = false
	p.try_step(Vector2i.DOWN)  # off again
	not_ok(plate.pressed, "plate releases the moment the cell is vacated")
	g.queue_free()


func test_block_press_is_persistent() -> void:
	var g := _make_grid()
	var plate := _plate(g, Vector2i(3, 3))
	var b := PushableBlock.new()
	g.register(b, Vector2i(3, 4))
	b.try_push(Vector2i.UP)   # onto the plate
	ok(plate.pressed, "a block parked on the plate presses it")
	g.queue_free()


func test_plate_door_opens_and_relocks() -> void:
	var g := _make_grid()
	var plate := _plate(g, Vector2i(3, 3))
	var door := _door(g, Vector2i(5, 3))
	_wire([plate], [door])
	ok(door.plate_driven, "wiring marks the door plate-driven")
	not_ok(g.is_walkable(door.cell), "door cell blocked while the plate is up")
	var p := Player.new()
	g.register(p, Vector2i(3, 4))
	p.try_step(Vector2i.UP)
	ok(door.held_open, "pressing the plate holds the door open")
	ok(g.is_walkable(door.cell), "door cell walkable while pressed")
	p.moving = false
	p.try_step(Vector2i.DOWN)
	not_ok(door.held_open, "releasing the plate drops the hold")
	not_ok(g.is_walkable(door.cell), "door re-locked on release")
	ok(g.blocked.has(door.cell), "re-locked door blocks pathing again")
	g.queue_free()


func test_relock_waits_for_doorway_to_clear() -> void:
	var g := _make_grid()
	var plate := _plate(g, Vector2i(3, 3))
	var door := _door(g, Vector2i(5, 3))
	_wire([plate], [door])
	# A block holds the plate; the player walks into the open doorway.
	var b := PushableBlock.new()
	g.register(b, Vector2i(3, 4))
	b.try_push(Vector2i.UP)
	b.moving = false
	var p := Player.new()
	g.register(p, Vector2i(5, 4))
	p.try_step(Vector2i.UP)   # into the doorway cell
	p.moving = false
	eq(p.cell, door.cell, "player is standing in the open doorway")
	# Now the plate releases while the player is inside the doorway.
	b.try_push(Vector2i.DOWN)
	b.moving = false
	not_ok(door.held_open, "plate released")
	eq(g.get_occupant(door.cell), p, "door never closes onto the player")
	not_ok(g.blocked.has(door.cell), "doorway not re-blocked while occupied")
	# The player steps on through; the door re-locks behind them.
	p.try_step(Vector2i.UP)
	p.moving = false
	eq(g.get_occupant(door.cell), door, "door re-locked once the doorway cleared")
	ok(g.blocked.has(door.cell), "cleared doorway blocks again")
	g.queue_free()


func test_prepressed_plate_opens_door_at_wire_time() -> void:
	var g := _make_grid()
	var plate := _plate(g, Vector2i(3, 3))
	var b := PushableBlock.new()
	g.register(b, Vector2i(3, 3))   # block already parked on the plate
	var door := _door(g, Vector2i(5, 3))
	_wire([plate], [door])
	ok(door.held_open, "a plate already pressed at wire-time opens its door")
	g.queue_free()


func test_key_door_unaffected_by_plates() -> void:
	var g := _make_grid()
	var plate := _plate(g, Vector2i(3, 3), "door_x")
	var door := _door(g, Vector2i(5, 3), "door_a")   # ids do NOT match
	_wire([plate], [door])
	not_ok(door.plate_driven, "unmatched door stays a key door")
	var p := Player.new()
	g.register(p, Vector2i(3, 4))
	p.try_step(Vector2i.UP)
	not_ok(door.held_open, "pressing an unrelated plate leaves the door shut")
	g.queue_free()


func test_latching_lever_toggles_linked_door() -> void:
	var g := _make_grid()
	var door := _door(g, Vector2i(5, 3))
	var lever := _lever(g, Vector2i(2, 3))
	_wire([], [door], [lever])
	ok(door.plate_driven, "linked lever marks the door mechanism-driven")
	not_ok(lever.latched, "lever starts off")
	lever.interact()
	ok(lever.latched and door.held_open, "first pull latches on and opens door")
	ok(g.is_walkable(door.cell), "latched-open door is walkable")
	lever.interact()
	not_ok(lever.latched or door.held_open, "second pull latches off and closes door")
	not_ok(g.is_walkable(door.cell), "latched-off door blocks again")
	g.queue_free()
