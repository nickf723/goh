extends "res://scripts/actions/firewall_cast.gd"
class_name FirewallCastSurfaceSafe

# Firewall keeps the generic surface-path implementation in its base action.
# This authority layer owns player-facing pointer routing, Focus interruption,
# and the integer midpoint required by the shared fire light.

var spell_aim_pointer: PlayerSpellAimPointer


func execute(player: Node3D, cast_direction: Vector3) -> void:
	_begin_spell_pointer(player)
	super.execute(player, cast_direction)


func _exit_tree() -> void:
	_end_spell_pointer("scene_exit")
	super._exit_tree()


func finish_drawing(
	reason: String = "released",
	ignite: bool = true
) -> void:
	# Keep the pointer alive through the base action's final surface sample, then
	# return camera control as soon as the line begins erupting.
	super.finish_drawing(reason, ignite)
	_end_spell_pointer(reason)


func cancel_drawing(reason: String = "cancelled") -> void:
	super.cancel_drawing(reason)
	_end_spell_pointer(reason)


func finish_firewall(reason: String = "complete") -> void:
	super.finish_firewall(reason)
	_end_spell_pointer(reason)


func _drawing_interrupted() -> bool:
	if super._drawing_interrupted():
		return true
	if action_state != null and action_state.is_focus_menu_open:
		return true
	return (
		spell_aim_pointer != null
		and spell_aim_pointer.is_aim_active()
		and not spell_aim_pointer.is_owned_by(self)
	)


func _resolve_surface_hit() -> Dictionary:
	if spell_aim_pointer == null or not spell_aim_pointer.is_owned_by(self):
		return super._resolve_surface_hit()

	var ray: Dictionary = spell_aim_pointer.get_world_ray(targeting_range)
	var ray_origin: Vector3 = ray.get(
		"origin",
		_get_cast_origin()
	) as Vector3
	var ray_direction: Vector3 = ray.get(
		"direction",
		_get_fallback_aim_direction()
	) as Vector3
	if ray_direction.length_squared() <= 0.0001:
		ray_direction = _get_fallback_aim_direction()
	ray_direction = ray_direction.normalized()
	var ray_end: Vector3 = ray_origin + ray_direction * targeting_range
	var result: Dictionary = {
		"valid": false,
		"ray_end": ray_end,
		"position": ray_end,
		"normal": Vector3.UP,
		"collider": null,
	}
	var world: World3D = source_actor.get_world_3d() if source_actor != null else null
	if world == null:
		spell_aim_pointer.set_target_state(
			false,
			"FIREWALL • NO WORLD SURFACE"
		)
		return result

	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		targeting_collision_mask
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = collision_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		spell_aim_pointer.set_target_state(
			false,
			"FIREWALL • NO DRAWABLE SURFACE"
		)
		return result

	var collider_value: Variant = hit.get("collider")
	if not collider_value is Node:
		spell_aim_pointer.set_target_state(
			false,
			"FIREWALL • INVALID SURFACE"
		)
		return result
	var collider: Node = collider_value as Node
	if not _is_valid_surface_collider(collider):
		spell_aim_pointer.set_target_state(
			false,
			"FIREWALL • SURFACE REJECTED"
		)
		return result

	var position_value: Variant = hit.get("position")
	var normal_value: Variant = hit.get("normal")
	if not position_value is Vector3 or not normal_value is Vector3:
		spell_aim_pointer.set_target_state(
			false,
			"FIREWALL • INVALID CONTACT"
		)
		return result
	var normal: Vector3 = normal_value as Vector3
	if normal.length_squared() <= 0.0001:
		spell_aim_pointer.set_target_state(
			false,
			"FIREWALL • INVALID NORMAL"
		)
		return result
	normal = normal.normalized()
	result["valid"] = true
	result["position"] = position_value as Vector3
	result["normal"] = normal
	result["collider"] = collider
	spell_aim_pointer.set_target_state(
		true,
		"FIREWALL • " + _classify_surface_normal(normal).to_upper()
	)
	return result


func _begin_spell_pointer(player: Node3D) -> void:
	if player == null:
		return
	spell_aim_pointer = player.get_node_or_null(
		"SpellAimPointer"
	) as PlayerSpellAimPointer
	if spell_aim_pointer == null:
		return
	spell_aim_pointer.begin_aim(self, {
		"mode_id": "firewall_surface",
		"capture_look": true,
		"initial_normalized_position": Vector2(0.5, 0.64),
		"horizontal_overflow_screens": 0.65,
		"vertical_overflow_screens": 1.25,
		"color": Color(1.0, 0.34, 0.08, 1.0),
		"status_text": "FIREWALL • FIND A DRAWABLE SURFACE",
		"target_valid": false,
	})


func _end_spell_pointer(reason: String) -> void:
	if spell_aim_pointer != null and spell_aim_pointer.is_owned_by(self):
		spell_aim_pointer.end_aim(self, reason)


func _update_firewall_visuals(force: bool) -> void:
	# The base renderer owns all MultiMesh transforms. Temporarily withhold the
	# shared light so its legacy midpoint expression cannot index with a float,
	# then update the same light using an explicit integer midpoint below.
	var retained_light: OmniLight3D = fire_light
	fire_light = null
	super._update_firewall_visuals(force)
	fire_light = retained_light
	_update_surface_safe_fire_light()


func _update_surface_safe_fire_light() -> void:
	if fire_light == null or path_points.is_empty():
		return
	var midpoint_index: int = clampi(
		floori(float(path_points.size()) * 0.5),
		0,
		path_points.size() - 1
	)
	var midpoint_data: Dictionary = path_points[midpoint_index]
	var light_position: Vector3 = midpoint_data.get(
		"position",
		Vector3.ZERO
	) as Vector3
	var light_normal: Vector3 = midpoint_data.get(
		"normal",
		Vector3.UP
	) as Vector3
	fire_light.global_position = (
		light_position + light_normal * minf(wall_height * 0.55, 1.2)
	)
	fire_light.light_energy = (
		(2.1 + 0.35 * sin(wall_elapsed * 17.0))
		* current_height_ratio
		* clampf(current_fade_alpha, 0.0, 1.0)
	)
	fire_light.omni_range = clampf(
		4.0 + path_length * 0.18,
		4.0,
		8.5
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["surface_safe_renderer"] = true
	data["integer_light_midpoint"] = true
	data["focus_interrupts_drawing"] = true
	data["spell_pointer_ready"] = spell_aim_pointer != null
	data["spell_pointer_owned"] = (
		spell_aim_pointer != null and spell_aim_pointer.is_owned_by(self)
	)
	data["pointer_surface_ray"] = true
	return data
