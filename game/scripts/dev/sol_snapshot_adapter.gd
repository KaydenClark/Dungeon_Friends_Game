extends RefCounted
## T-097: tiny, isolated seam for Sol's T-096 formation/deployment planner
## output (SOL_FABLE_PIVOT_FIX_HANDOFF.md -> Shared seam). The neutral
## snapshot contract is:
##
##   {formation_id, leader_id, facing,
##    member_cells: {member_id: cell},
##    deployment_cells: {member_id: legal_reachable_cell}}
##
## Fable consumes only the member ids/cells/deployment cells at encounter
## entry. Deliberately NO breadcrumb, formation, or fallback logic here -
## those algorithms are Sol's. This file stays a dumb mapping while the
## encounter scene supplies the real planner output.


## Encounter-start cells for the given party ids: the deployment cell when
## the planner produced one, else the member's current cell. Ids the snapshot
## does not know are skipped (the caller keeps their current position).
static func encounter_start_cells(snapshot: Dictionary, ids: Array) -> Dictionary:
	var member_cells: Dictionary = snapshot.get("member_cells", {})
	var deployment_cells: Dictionary = snapshot.get("deployment_cells", {})
	var cells := {}
	for id: String in ids:
		if deployment_cells.has(id):
			cells[id] = deployment_cells[id]
		elif member_cells.has(id):
			cells[id] = member_cells[id]
	return cells
