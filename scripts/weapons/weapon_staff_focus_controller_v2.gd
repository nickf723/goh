extends "res://scripts/weapons/weapon_staff_focus_controller_v1.gd"
class_name WeaponStaffFocusControllerV2


func _stabilize_staff_mount(delta: float) -> void:
	if not is_staff_angel_ring_charging():
		return
	var actor: Node3D = get_actor()
	if not actor is CharacterBody3D:
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	var braking: float = maxf(delta, 0.0) * 30.0
	body.velocity.x = move_toward(body.velocity.x, 0.0, braking)
	body.velocity.z = move_toward(body.velocity.z, 0.0, braking)


func _update_charge_hold_heading(delta: float) -> void:
	if (
		charge_active
		and str(charge_profile.get("id", "")) == "axe_lever_vault"
	):
		var actor: Node3D = get_actor()
		if actor == null:
			return
		if not staff_charge_heading_initialized:
			staff_charge_heading = _get_actor_planar_forward(actor)
			staff_charge_heading_initialized = true
		var desired: Vector3 = _get_staff_stick_world_direction()
		if desired.length_squared() > 0.0001:
			staff_charge_heading = _rotate_heading_toward(
				staff_charge_heading,
				desired,
				staff_charge_turn_degrees_per_second,
				delta,
				_get_staff_stick_strength()
			)
		attack_forward_override = staff_charge_heading
		_apply_actor_heading(staff_charge_heading)
		return
	super._update_charge_hold_heading(delta)


func get_staff_focus_v2_debug_data() -> Dictionary:
	return {
		"staff_focus_v2": true,
		"ring_velocity_brake": true,
		"global_charge_turn_rate_limit": true,
	}
