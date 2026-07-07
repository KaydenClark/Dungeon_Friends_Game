extends GridActor
## Test double: a GridActor that records the occupant it last bumped, so the
## GridActor suite can assert that a blocked step routes through _on_bump()
## instead of moving. Mirrors how Player._on_bump() hooks the same override.

var bumped: Node2D = null


func _on_bump(occ: Node2D) -> void:
	bumped = occ
