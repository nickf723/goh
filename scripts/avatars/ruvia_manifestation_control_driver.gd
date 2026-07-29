extends "res://scripts/avatars/companion_avatar_control_driver.gd"
class_name RuviaManifestationControlDriver

@export_range(0.02, 0.5, 0.01) var failed_action_retry_seconds: float = 0.08


func _ready() -> void:
	super._ready()
	driver_id = "ruvia_companion_ai"
	display_name = "Ruvia Companion AI"
	add_to_group("ruvia_manifestation_control_driver")


func notify_action_result(
	action_kind: String,
	action_id: String,
	success: bool
) -> void:
	super.notify_action_result(action_kind, action_id, success)
	if not success:
		decision_remaining = maxf(
			decision_remaining,
			failed_action_retry_seconds
		)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["failed_action_retry"] = failed_action_retry_seconds
	data["avatar_specialist"] = "ruvia"
	return data
