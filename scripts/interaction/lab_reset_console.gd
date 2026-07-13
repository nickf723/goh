extends Area3D
class_name LabResetConsole

@export var prompt_text: String = "Reset reaction laboratory"


func _ready() -> void:
	add_to_group("debuggable")


func interact() -> Dictionary:
	var scene_root: Node = get_tree().current_scene

	if scene_root != null and scene_root.has_method("reset_lab"):
		scene_root.reset_lab()
		return {
			"message": "The laboratory returns to its baseline state.",
			"objective": "Trigger all six elemental reactions."
		}

	return {
		"message": "The reset console cannot find the laboratory director.",
		"objective": ""
	}


func get_debug_data() -> Dictionary:
	return {
		"reset_console": "ready",
	}
