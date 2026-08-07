extends "res://scripts/actions/earth_boulder.gd"
class_name EarthBoulderReady

# The shared Boulder owns physics, impact payloads, lifetime, and presentation.
# This production authority applies the no-slip roll direction after the shared
# launch calculation. For a surface normal n and travel direction v, angular
# velocity follows n × v so the contact point moves opposite the center velocity.

@export_range(1, 8, 1) var maximum_active_boulders_per_caster: int = 3


func execute(player: Node3D, requested_direction: Vector3) -> void:
	super.execute(player, requested_direction)
	if not active or dissipating:
		return

	var roll_axis: Vector3 = launch_surface_normal.cross(surface_direction)
	if roll_axis.length_squared() <= 0.0001:
		roll_axis = Vector3.UP.cross(surface_direction)
	if roll_axis.length_squared() <= 0.0001:
		roll_axis = Vector3.RIGHT
	roll_axis = roll_axis.normalized()
	angular_velocity = roll_axis * (
		initial_roll_speed / maxf(boulder_radius, 0.05)
	)
	_enforce_active_boulder_budget()


func _enforce_active_boulder_budget() -> void:
	var owned_boulders: Array[Node] = []
	for candidate: Node in get_tree().get_nodes_in_group(
		"earth_boulder_effects"
	):
		if (
			candidate == null
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
			or not candidate.has_method("belongs_to_source")
			or not bool(candidate.call("belongs_to_source", source_actor))
		):
			continue
		owned_boulders.append(candidate)

	owned_boulders.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get("cast_serial")) < int(b.get("cast_serial"))
	)
	var safe_limit: int = maxi(maximum_active_boulders_per_caster, 1)
	while owned_boulders.size() > safe_limit:
		var oldest: Node = owned_boulders.pop_front()
		if oldest == null or not is_instance_valid(oldest):
			continue
		if oldest.has_method("begin_dissolve"):
			oldest.call("begin_dissolve", "active_boulder_budget", false)
		else:
			oldest.queue_free()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["no_slip_roll_axis"] = true
	data["roll_axis"] = (
		angular_velocity.normalized()
		if angular_velocity.length_squared() > 0.0001
		else Vector3.ZERO
	)
	data["maximum_active_per_caster"] = maximum_active_boulders_per_caster
	return data
