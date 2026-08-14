extends "res://scripts/weapons/axe_weapon_rig_v1.gd"
class_name AxeWeaponRigV2

# V2 adds the charge-Light catch/reversal and makes aerial intent explicit. The
# edge remains rolled into the actual swing plane throughout every vertical cut.


func _process(_delta: float) -> void:
	_update_momentum_glow()


func get_support_grip_influence() -> float:
	if active_attack != null and (
		active_attack.extra_tags.has("axe_counter_guard")
		or active_attack.extra_tags.has("axe_counter_reversal")
		or active_attack.extra_tags.has("axe_aerial_crash")
	):
		return 0.98
	return super.get_support_grip_influence()


func _update_attack_pose() -> void:
	if active_attack == null:
		super._update_attack_pose()
		return
	_update_momentum_glow()
	if active_attack.extra_tags.has("axe_counter_guard"):
		_update_counter_guard_pose()
		return
	if active_attack.extra_tags.has("axe_counter_reversal"):
		_update_counter_reversal_pose()
		return
	if active_attack.extra_tags.has("axe_aerial_drive"):
		_update_side_hew_pose()
		return
	if active_attack.extra_tags.has("axe_aerial_crash"):
		_update_overhead_pose()
		return
	# Rising Wedge is edge-aligned too, so it must be resolved before the parent's
	# broad edge-aligned overhead branch.
	if active_attack.extra_tags.has("axe_rising"):
		_update_rising_pose()
		return
	super._update_attack_pose()


func _update_counter_guard_pose() -> void:
	var timing: float = 0.0
	if controller != null and controller.has_method("get_axe_counter_timing_ratio"):
		timing = clampf(
			float(controller.call("get_axe_counter_timing_ratio")),
			0.0,
			1.0
		)
	var pulse: float = sin(active_elapsed * 34.0) * timing
	position = Vector3(
		0.0,
		0.035 + pulse * 0.008,
		-0.18 - timing * 0.025
	)
	rotation_degrees = Vector3(
		-8.0 - timing * 3.0,
		-72.0 + pulse * 2.5,
		88.0 + timing * 2.0
	)
	if accent_material != null:
		var momentum: float = 0.0
		if controller != null and controller.has_method("get_axe_momentum_ratio"):
			momentum = clampf(
				float(controller.call("get_axe_momentum_ratio")),
				0.0,
				1.0
			)
		accent_material.emission_energy_multiplier = maxf(
			lerpf(0.7, 1.9, momentum),
			lerpf(0.9, 2.8, timing)
		)


func _update_counter_reversal_pose() -> void:
	var phase: Dictionary = _get_attack_phase()
	rotation_degrees = _sample_phase_vector(
		Vector3(-10.0, -78.0, 88.0),
		Vector3(-9.0, 110.0, 90.0),
		Vector3(-14.0, 142.0, 88.0),
		Vector3(-18.0, 22.0, 82.0),
		phase
	)
	position = _sample_phase_vector(
		Vector3(0.0, 0.025, -0.16),
		Vector3(0.035, -0.055, -0.36),
		Vector3(0.06, -0.07, -0.44),
		Vector3.ZERO,
		phase
	)
	if accent_material != null:
		accent_material.emission_energy_multiplier = 2.5


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["axe_weapon_rig_v2"] = true
	data["live_momentum_glow"] = true
	data["counter_guard_pose"] = true
	data["counter_reversal_pose"] = true
	data["authored_aerial_pose_routing"] = true
	return data
