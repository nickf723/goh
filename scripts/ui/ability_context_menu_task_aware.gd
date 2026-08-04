extends "res://scripts/ui/persistent_ability_context_menu_unified.gd"
class_name AbilityContextMenuTaskAware

const FAMILIAR_TASK_COLLISION_LAYER: int = 1 << 19

var target_payload: Variant = Vector3.ZERO
var target_preview: Dictionary = {}
var last_target_collider: Variant


func confirm_current_target() -> bool:
	if not targeting_active or not target_valid:
		return false
	var action_id: String = get_selected_action_id()
	if action_id == "":
		return false
	var succeeded: bool = _execute_action(action_id, target_payload)
	if succeeded:
		targeting_confirm_count += 1
	return succeeded


func confirm_world_target(world_position: Vector3) -> bool:
	target_payload = world_position
	return super.confirm_world_target(world_position)


func _update_targeting_position() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		target_valid = false
		return
	var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var origin: Vector3 = camera.project_ray_origin(screen_center)
	var direction: Vector3 = camera.project_ray_normal(screen_center).normalized()
	var end: Vector3 = origin + direction * targeting_distance
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		end,
		1 | FAMILIAR_TASK_COLLISION_LAYER
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _get_actor_collision_exclusions()
	var result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	var raw_valid: bool = false
	last_target_collider = result.get("collider")
	if result.has("position"):
		target_position = result.get("position", Vector3.ZERO) as Vector3
		raw_valid = true
	else:
		var plane := Plane(Vector3.UP, 0.0)
		var intersection: Variant = plane.intersects_ray(origin, direction)
		if intersection is Vector3:
			target_position = intersection as Vector3
			raw_valid = origin.distance_to(target_position) <= targeting_distance
		else:
			raw_valid = false

	target_preview = _get_provider_target_preview(
		get_selected_action_id(),
		target_position,
		last_target_collider,
		raw_valid
	)
	target_valid = raw_valid and bool(target_preview.get("valid", true))
	target_position = target_preview.get("position", target_position) as Vector3
	target_payload = target_preview.get("payload", target_position)

	_ensure_target_marker()
	if target_marker != null:
		target_marker.visible = raw_valid
		if raw_valid:
			target_marker.global_position = target_position + Vector3.UP * 0.06
	var label: String = str(target_preview.get("label", "GO THERE"))
	var description: String = str(target_preview.get("description", ""))
	if not raw_valid:
		target_label.text = "Aim at reachable ground or a familiar task"
	elif not target_valid:
		target_label.text = label.to_upper() + "\n" + description
	else:
		target_label.text = (
			label.to_upper()
			+ ("\n" + description if description != "" else "")
			+ "\nCAST: confirm   B: cancel"
		)


func _get_provider_target_preview(
	action_id: String,
	world_position: Vector3,
	collider: Variant,
	raw_valid: bool
) -> Dictionary:
	if not raw_valid:
		return {
			"valid": false,
			"label": "NO TARGET",
			"description": "Aim at reachable ground or a familiar task.",
			"position": world_position,
			"payload": world_position,
		}
	if _provider_is_usable(provider) and provider.has_method("get_ability_context_target_preview"):
		var value: Variant = provider.call(
			"get_ability_context_target_preview",
			action_id,
			world_position,
			collider
		)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {
		"valid": true,
		"label": "GO THERE",
		"description": "Confirm the aimed world position.",
		"position": world_position,
		"payload": world_position,
	}


func get_target_preview() -> Dictionary:
	return target_preview.duplicate(true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["task_aware_targeting"] = {
		"preview": target_preview.duplicate(true),
		"payload_is_task": target_payload is Dictionary,
		"collider": str(last_target_collider) if last_target_collider != null else "none",
	}
	return data
