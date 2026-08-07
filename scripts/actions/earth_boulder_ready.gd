extends "res://scripts/actions/earth_boulder.gd"
class_name EarthBoulderReady

# The shared Boulder owns physics, impact payloads, lifetime, and presentation.
# This production authority applies the no-slip roll direction after the shared
# launch calculation. For a surface normal n and travel direction v, angular
# velocity follows n × v so the contact point moves opposite the center velocity.


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


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["no_slip_roll_axis"] = true
	data["roll_axis"] = (
		angular_velocity.normalized()
		if angular_velocity.length_squared() > 0.0001
		else Vector3.ZERO
	)
	data["motion_is_only_normal_lifetime_rule"] = true
	return data
