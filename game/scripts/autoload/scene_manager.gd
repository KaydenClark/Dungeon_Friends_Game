extends Node
## The project's one and only autoload (locked architecture decision, see
## /BLUEPRINT.md -> Architecture). Owns transient session state (current map,
## player spawn point, active party reference, pending encounter data) and
## the GameState/SaveData resource. Data-decoupling lives in Resource (.tres)
## classes under scripts/data/, so this stays a coordinator, not a junk drawer
## of global variables.

func _ready() -> void:
	print("SceneManager ready.")
