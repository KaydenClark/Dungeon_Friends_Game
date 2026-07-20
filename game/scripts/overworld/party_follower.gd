class_name PartyFollower
extends GridActor
## S-009/TK-003 render-only exploration party member (D-029). Reuses the
## GridActor sprite/facing presentation but is deliberately NEVER registered
## in the room's occupancy map: followers cannot block the leader, press
## plates, push blocks, or trigger bumps. Movement is a plain position glide
## driven by the room's PartyTrail model, not try_step.

var member_id := ""
var _glide: Tween


func setup(id: String, stats: CharacterStats, grid: RoomGrid,
		start_cell: Vector2i) -> void:
	member_id = id
	room = grid   # for cell_to_pos math only - never an occupant
	cell = start_cell
	position = grid.cell_to_pos(start_cell)
	move_time = 0.16   # match the leader's WALK_MOVE_TIME pace
	var frames: SpriteFrames = stats.sprite_frames if stats != null else null
	if not _make_sprite(frames, 0.5):
		_make_body(Color(0.35, 0.7, 0.55))


## Glide (or snap, for teleports/reseeds) to a trail cell. No occupancy, no
## bump, no walkability check - the PartyTrail model already chose a legal
## render cell.
func glide_to(target: Vector2i, instant := false) -> void:
	if room == null or target == cell:
		return
	var step := target - cell
	if absi(step.x) + absi(step.y) == 1:
		set_facing(step)
	cell = target
	# A frame hitch can let glides overlap; the stale tween would fight the
	# new one over `position` (TK-003 review F1), so kill it first.
	if _glide != null and _glide.is_valid():
		_glide.kill()
	var target_pos: Vector2 = room.cell_to_pos(target)
	if instant:
		position = target_pos
		return
	_glide = create_tween()
	_glide.tween_property(self, "position", target_pos, move_time)
