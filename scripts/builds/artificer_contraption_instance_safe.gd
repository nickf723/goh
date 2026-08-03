extends "res://scripts/builds/artificer_contraption_instance.gd"
class_name ArtificerContraptionInstanceSafe


func _refresh_visual_state() -> void:
	if visual_root == null:
		return
	var tint := Color(0.0, 0.0, 0.0, 1.0)
	var energy: float = 0.0
	if frozen_progress >= 0.65:
		tint = Color(0.3, 0.8, 1.0, 1.0)
		energy = 0.8
	elif energized_remaining > 0.0:
		tint = Color(0.55, 0.62, 1.0, 1.0)
		energy = 1.35
	elif wet_remaining > 0.0:
		tint = Color(0.22, 0.48, 0.9, 1.0)
		energy = 0.25
	for node: Node in visual_root.find_children("PartVisual", "MeshInstance3D", true, false):
		if not node is MeshInstance3D:
			continue
		var material: StandardMaterial3D = (
			(node as MeshInstance3D).material_override as StandardMaterial3D
		)
		if material == null:
			continue
		material.emission_enabled = energy > 0.0
		material.emission = tint
		material.emission_energy_multiplier = energy


func _apply_buoyancy() -> void:
	submerged_fraction = 0.0
	active_fluid_volume = null
	var float_count: int = int(features.get("floats", 0))
	if freeze or float_count <= 0 or get_tree() == null:
		return
	var best_priority: int = -2147483648
	for node: Node in get_tree().get_nodes_in_group("fluid_force_volumes"):
		var volume := node as FluidForceVolume
		if volume == null or not is_instance_valid(volume):
			continue
		var fraction: float = volume.get_submerged_fraction(
			global_position + Vector3.UP * body_size.y * 0.5,
			body_size.y,
			0.05
		)
		if fraction <= 0.0:
			continue
		if volume.priority > best_priority or fraction > submerged_fraction:
			active_fluid_volume = volume
			submerged_fraction = fraction
			best_priority = volume.priority
	if active_fluid_volume == null or submerged_fraction <= 0.0:
		return
	wet_remaining = maxf(wet_remaining, 1.2)
	var gravity_value: float = maxf(float(ProjectSettings.get_setting(
		"physics/3d/default_gravity",
		9.8
	)), 0.1)
	var ratio: float = clampf(0.75 + float_count * 0.28, 0.9, 1.75)
	apply_central_force(
		Vector3.UP * mass * gravity_value * ratio * submerged_fraction
	)
	var flow: Vector3 = active_fluid_volume.get_flow_velocity_at(global_position)
	apply_central_force((flow - linear_velocity) * mass * submerged_fraction * 1.4)
	linear_velocity *= 0.992
	angular_velocity *= 0.965
