class_name PushableBlock
extends GridActor
## Pushable puzzle block (T-023, movement roadmap row 3). The player walks
## into it while pressing toward it (Player._on_bump calls try_push); the
## block tweens exactly one cell if the destination is free. Push-only at
## MVP - pull is deliberately not in scope. The block occupies its cell, so
## pathing and other actors treat it as solid.
##
## Pushed into a pit cell it sinks and fills the pit, permanently converting
## that cell to walkable floor (T-025 / classic Zelda; locked decision).

## LDtk link id so plates/controllers can reference a specific block.
@export var link_id := ""
## False = a fixed brick: looks identical to a pushable block but never
## moves (the Oracle-style "find the brick that budges" wall - Kayden
## 2026-07-07). Fixed bricks still occupy and block their cell.
@export var movable := true
## Where the block started; the reset lever / dev tools send it back here.
var start_cell := Vector2i.ZERO
## True once the block has filled a pit: it is floor now - no longer an
## occupant, no longer pushable, and excluded from puzzle resets.
var sunk := false


func _ready() -> void:
	# Blocks must cover floor switches when used as their persistent weight.
	z_index = 1
	# Placeholder art until the post-Phase-2 art pass: a stone-grey slab with
	# a lighter top face so it reads as a heavy, grabbable object.
	body = ColorRect.new()
	body.color = Color(0.44, 0.42, 0.4)
	body.position = Vector2(-26, -26)
	body.size = Vector2(52, 52)
	add_child(body)
	var top := ColorRect.new()
	top.color = Color(0.58, 0.56, 0.52)
	top.position = Vector2(-26, -26)
	top.size = Vector2(52, 14)
	add_child(top)


func attach(p_room: RoomGrid, p_cell: Vector2i) -> void:
	super.attach(p_room, p_cell)
	start_cell = p_cell


## Attempt a one-cell push in `dir`. Returns true when the block moves (into
## a free cell or down into a pit). Refused while a previous push is still
## tweening, after sinking, into walls/pits-behind-occupants/other occupants,
## or out of bounds.
func try_push(dir: Vector2i) -> bool:
	if not movable or moving or sunk or room == null or dir == Vector2i.ZERO:
		return false
	var target := cell + dir
	if not room.in_bounds(target):
		return false
	if room.no_block_cells.has(target):
		return false  # never plug a doorway (soft-lock by construction)
	if room.get_occupant(target) != null:
		return false
	if room.is_pit(target):
		_sink_into(target)
		return true
	if room.blocked.has(target):
		return false
	_start_move(target)
	return true


## Slide into the pit cell and become floor: the pit fills permanently, the
## block leaves the occupancy map (the cell must be walkable now), and it
## stays visible as the filler.
func _sink_into(pit_cell: Vector2i) -> void:
	moving = true
	room.vacate(self)
	cell = pit_cell
	var tw := create_tween()
	tw.tween_property(self, "position", room.cell_to_pos(pit_cell), move_time)
	await tw.finished
	room.fill_pit(pit_cell)
	sunk = true
	moving = false
	# Flatten the colors so the filled cell reads as floor, not obstacle.
	body.color = Color(0.35, 0.33, 0.31)
	for child in get_children():
		if child is ColorRect and child != body:
			child.visible = false
	move_finished.emit()


## Send the block back to its starting cell (reset lever / dev tools). Sunk
## blocks are floor and never come back - filled pits are permanent.
func reset_to_start() -> void:
	if sunk or room == null or cell == start_cell:
		return
	if room.get_occupant(start_cell) != null and room.get_occupant(start_cell) != self:
		return  # something is standing there; the reset stays a no-op for this block
	room.move_occupant(self, cell, start_cell)
	cell = start_cell
	position = room.cell_to_pos(start_cell)
