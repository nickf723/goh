extends "res://scripts/weapons/chain_weapon_rig_v5.gd"
class_name ChainWeaponRigV6


func _physics_process(delta: float) -> void:
	var momentum: float = _get_controller_momentum()
	head_response = lerpf(5.4, 9.2, momentum)
	head_max_speed = lerpf(13.5, 23.0, momentum)
	line_sag = lerpf(0.82, 0.54, momentum)
	super._physics_process(delta)


func _idle_tip() -> Vector3:
	if handle_anchor == null:
		return global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var momentum: float = _get_controller_momentum()
	if momentum <= 0.01:
		var dragged: Vector3 = (
			handle_anchor.global_position
			- forward * 0.72
			+ right * 0.48
			+ Vector3.DOWN * 0.68
		)
		return _ground_project(dragged)

	var seconds: float = float(Time.get_ticks_msec()) * 0.001
	var orbit_speed: float = lerpf(1.8, 3.6, momentum)
	var angle: float = seconds * orbit_speed
	var radius: float = lerpf(1.15, 2.05, momentum)
	var orbit_point: Vector3 = handle_anchor.global_position
	orbit_point += forward * cos(angle) * radius
	orbit_point += right * sin(angle) * radius
	return _ground_project(orbit_point) + Vector3.UP * lerpf(0.08, 0.2, momentum)


func _get_controller_momentum() -> float:
	if controller != null and controller.has_method("get_chain_momentum_ratio"):
		return clampf(float(controller.call("get_chain_momentum_ratio")), 0.0, 1.0)
	return 0.0


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "momentum_chain_v6"
	data["momentum_ratio"] = snappedf(_get_controller_momentum(), 0.01)
	data["idle_orbit_from_momentum"] = true
	return data
