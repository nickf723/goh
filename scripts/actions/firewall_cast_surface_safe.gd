extends "res://scripts/actions/firewall_cast.gd"
class_name FirewallCastSurfaceSafe

# Keep the production spell focused on the generic surface-path implementation,
# while this thin authority layer hardens two player-facing edges: opening Focus
# cancels an unfinished drawing, and the path midpoint used by the shared fire
# light is always an integer array index.


func _drawing_interrupted() -> bool:
	if super._drawing_interrupted():
		return true
	return action_state != null and action_state.is_focus_menu_open


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
	return data
