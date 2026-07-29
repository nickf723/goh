extends "res://scripts/avatars/companion_avatar_control_driver.gd"
class_name RuviaManifestationControlDriver

@export_range(0.02, 0.5, 0.01) var failed_action_retry_seconds: float = 0.08


func _ready() -> void:
	super._ready()
	driver_id = "companion_ai"
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


func _get_owned_fields() -> Array[Node]:
	var fields: Array[Node] = []
	if controlled_actor == null:
		return fields
	var authority: Node = controlled_actor.get_node_or_null(
		"ElementalAuthorityController"
	)
	if authority == null or not authority.has_method("get_owned_fields"):
		return fields
	var fields_value: Variant = authority.call("get_owned_fields")
	if not (fields_value is Array):
		return fields
	var raw_fields: Array = fields_value as Array
	for field_value: Variant in raw_fields:
		if field_value is Node and is_instance_valid(field_value):
			fields.append(field_value as Node)
	return fields


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["failed_action_retry"] = failed_action_retry_seconds
	data["avatar_specialist"] = "ruvia"
	return data
