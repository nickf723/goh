extends RefCounted
class_name WeaponCharacterPoseCatalog

const PROFILES: Dictionary = {
	"sword_cut_right": {
		"windup_body_rotation_degrees": Vector3(-5.0, -24.0, 4.0),
		"strike_body_rotation_degrees": Vector3(-8.0, 34.0, -4.0),
		"windup_head_rotation_degrees": Vector3(0.0, 8.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, -12.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-18.0, 10.0, -34.0),
		"strike_left_arm_rotation_degrees": Vector3(12.0, -8.0, 28.0),
		"windup_right_arm_rotation_degrees": Vector3(32.0, -12.0, 48.0),
		"strike_right_arm_rotation_degrees": Vector3(-78.0, 16.0, -26.0),
		"windup_right_hand_position": Vector3(0.02, 0.03, 0.04),
		"strike_right_hand_position": Vector3(-0.04, 0.02, -0.1),
		"windup_right_hand_rotation_degrees": Vector3(4.0, -8.0, -14.0),
		"strike_right_hand_rotation_degrees": Vector3(-6.0, 10.0, 18.0),
		"weapon_rotation_share": 0.24,
		"weapon_offset_share": 0.35,
	},
	"sword_cut_left": {
		"windup_body_rotation_degrees": Vector3(-5.0, 28.0, -4.0),
		"strike_body_rotation_degrees": Vector3(-8.0, -36.0, 4.0),
		"windup_head_rotation_degrees": Vector3(0.0, -9.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(10.0, -8.0, 26.0),
		"strike_left_arm_rotation_degrees": Vector3(-16.0, 8.0, -30.0),
		"windup_right_arm_rotation_degrees": Vector3(-72.0, 14.0, -26.0),
		"strike_right_arm_rotation_degrees": Vector3(-86.0, -18.0, 36.0),
		"windup_right_hand_position": Vector3(-0.02, 0.02, -0.08),
		"strike_right_hand_position": Vector3(0.05, 0.02, -0.11),
		"windup_right_hand_rotation_degrees": Vector3(-4.0, 10.0, 14.0),
		"strike_right_hand_rotation_degrees": Vector3(6.0, -10.0, -20.0),
		"weapon_rotation_share": 0.24,
		"weapon_offset_share": 0.35,
	},
	"sword_rising_right": {
		"windup_body_rotation_degrees": Vector3(6.0, -22.0, 7.0),
		"strike_body_rotation_degrees": Vector3(-12.0, 30.0, -7.0),
		"windup_head_rotation_degrees": Vector3(6.0, 7.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-7.0, -9.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-12.0, 4.0, -28.0),
		"strike_left_arm_rotation_degrees": Vector3(24.0, -6.0, 36.0),
		"windup_right_arm_rotation_degrees": Vector3(42.0, -14.0, 64.0),
		"strike_right_arm_rotation_degrees": Vector3(-122.0, 12.0, -48.0),
		"windup_right_hand_position": Vector3(0.03, -0.04, 0.05),
		"strike_right_hand_position": Vector3(-0.05, 0.11, -0.12),
		"windup_right_hand_rotation_degrees": Vector3(12.0, -8.0, -20.0),
		"strike_right_hand_rotation_degrees": Vector3(-18.0, 10.0, 28.0),
		"weapon_rotation_share": 0.28,
		"weapon_offset_share": 0.38,
	},
	"sword_spin_right": {
		"windup_body_rotation_degrees": Vector3(-4.0, -44.0, 7.0),
		"strike_body_rotation_degrees": Vector3(-8.0, 76.0, -8.0),
		"windup_head_rotation_degrees": Vector3(0.0, 14.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, -18.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-22.0, 12.0, -48.0),
		"strike_left_arm_rotation_degrees": Vector3(18.0, -10.0, 52.0),
		"windup_right_arm_rotation_degrees": Vector3(24.0, -14.0, 56.0),
		"strike_right_arm_rotation_degrees": Vector3(-92.0, 18.0, -42.0),
		"windup_right_hand_position": Vector3(0.03, 0.03, 0.05),
		"strike_right_hand_position": Vector3(-0.06, 0.04, -0.14),
		"windup_right_hand_rotation_degrees": Vector3(8.0, -12.0, -18.0),
		"strike_right_hand_rotation_degrees": Vector3(-10.0, 14.0, 24.0),
		"weapon_rotation_share": 0.42,
		"weapon_offset_share": 0.42,
	},
	"sword_thrust": {
		"windup_body_rotation_degrees": Vector3(-3.0, -10.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-14.0, 8.0, 0.0),
		"windup_head_rotation_degrees": Vector3(0.0, 3.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-4.0, -2.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-22.0, 6.0, -34.0),
		"strike_left_arm_rotation_degrees": Vector3(-42.0, -4.0, -18.0),
		"windup_right_arm_rotation_degrees": Vector3(-34.0, -4.0, 18.0),
		"strike_right_arm_rotation_degrees": Vector3(-96.0, 0.0, -6.0),
		"windup_right_hand_position": Vector3(0.0, 0.0, 0.04),
		"strike_right_hand_position": Vector3(0.0, 0.02, -0.2),
		"windup_right_hand_rotation_degrees": Vector3(0.0, -4.0, -4.0),
		"strike_right_hand_rotation_degrees": Vector3(-4.0, 4.0, 4.0),
		"weapon_rotation_share": 0.08,
		"weapon_offset_share": 0.25,
	},
	"sword_overhead": {
		"windup_body_rotation_degrees": Vector3(8.0, -6.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-18.0, 6.0, 0.0),
		"windup_head_rotation_degrees": Vector3(7.0, 2.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-8.0, -2.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-28.0, 6.0, -48.0),
		"strike_left_arm_rotation_degrees": Vector3(20.0, -4.0, 32.0),
		"windup_right_arm_rotation_degrees": Vector3(10.0, -8.0, 148.0),
		"strike_right_arm_rotation_degrees": Vector3(-64.0, 6.0, 18.0),
		"windup_right_hand_position": Vector3(-0.04, 0.12, 0.02),
		"strike_right_hand_position": Vector3(0.0, -0.02, -0.14),
		"windup_right_hand_rotation_degrees": Vector3(12.0, 0.0, -18.0),
		"strike_right_hand_rotation_degrees": Vector3(-14.0, 0.0, 12.0),
		"weapon_rotation_share": 0.18,
		"weapon_offset_share": 0.3,
	},
	"sword_rising_heavy": {
		"windup_body_rotation_degrees": Vector3(10.0, -28.0, 8.0),
		"strike_body_rotation_degrees": Vector3(-16.0, 34.0, -8.0),
		"windup_head_rotation_degrees": Vector3(8.0, 9.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-9.0, -11.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-18.0, 8.0, -36.0),
		"strike_left_arm_rotation_degrees": Vector3(28.0, -8.0, 42.0),
		"windup_right_arm_rotation_degrees": Vector3(58.0, -16.0, 72.0),
		"strike_right_arm_rotation_degrees": Vector3(-134.0, 14.0, -52.0),
		"windup_right_hand_position": Vector3(0.04, -0.05, 0.08),
		"strike_right_hand_position": Vector3(-0.06, 0.14, -0.15),
		"windup_right_hand_rotation_degrees": Vector3(14.0, -10.0, -24.0),
		"strike_right_hand_rotation_degrees": Vector3(-20.0, 12.0, 32.0),
		"weapon_rotation_share": 0.26,
		"weapon_offset_share": 0.4,
	},
	"sword_cleave_left": {
		"windup_body_rotation_degrees": Vector3(-6.0, 42.0, -6.0),
		"strike_body_rotation_degrees": Vector3(-12.0, -58.0, 6.0),
		"windup_head_rotation_degrees": Vector3(0.0, -14.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, 18.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(12.0, -8.0, 30.0),
		"strike_left_arm_rotation_degrees": Vector3(-24.0, 10.0, -40.0),
		"windup_right_arm_rotation_degrees": Vector3(-48.0, 18.0, -34.0),
		"strike_right_arm_rotation_degrees": Vector3(-96.0, -22.0, 44.0),
		"windup_right_hand_position": Vector3(-0.03, 0.03, -0.04),
		"strike_right_hand_position": Vector3(0.06, 0.03, -0.15),
		"windup_right_hand_rotation_degrees": Vector3(-8.0, 12.0, 18.0),
		"strike_right_hand_rotation_degrees": Vector3(10.0, -14.0, -24.0),
		"weapon_rotation_share": 0.34,
		"weapon_offset_share": 0.4,
	},
	"sword_thrust_heavy": {
		"windup_body_rotation_degrees": Vector3(-4.0, -12.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-18.0, 10.0, 0.0),
		"windup_head_rotation_degrees": Vector3(0.0, 4.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-6.0, -3.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-32.0, 8.0, -38.0),
		"strike_left_arm_rotation_degrees": Vector3(-50.0, -4.0, -22.0),
		"windup_right_arm_rotation_degrees": Vector3(-42.0, -4.0, 20.0),
		"strike_right_arm_rotation_degrees": Vector3(-108.0, 0.0, -8.0),
		"windup_right_hand_position": Vector3(0.0, 0.0, 0.05),
		"strike_right_hand_position": Vector3(0.0, 0.02, -0.25),
		"windup_right_hand_rotation_degrees": Vector3(0.0, -5.0, -5.0),
		"strike_right_hand_rotation_degrees": Vector3(-5.0, 5.0, 5.0),
		"weapon_rotation_share": 0.06,
		"weapon_offset_share": 0.18,
	},
	"sword_orbit": {
		"windup_body_rotation_degrees": Vector3(-5.0, -68.0, 8.0),
		"strike_body_rotation_degrees": Vector3(-12.0, 112.0, -10.0),
		"windup_head_rotation_degrees": Vector3(0.0, 20.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, -26.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-28.0, 14.0, -62.0),
		"strike_left_arm_rotation_degrees": Vector3(26.0, -12.0, 64.0),
		"windup_right_arm_rotation_degrees": Vector3(18.0, -18.0, 70.0),
		"strike_right_arm_rotation_degrees": Vector3(-100.0, 26.0, -50.0),
		"windup_right_hand_position": Vector3(0.04, 0.05, 0.06),
		"strike_right_hand_position": Vector3(-0.08, 0.05, -0.16),
		"windup_right_hand_rotation_degrees": Vector3(10.0, -14.0, -22.0),
		"strike_right_hand_rotation_degrees": Vector3(-12.0, 16.0, 28.0),
		"weapon_rotation_share": 0.46,
		"weapon_offset_share": 0.45,
	},
}


static func has_profile(profile_id: String) -> bool:
	return profile_id != "" and PROFILES.has(profile_id)


static func get_profile(profile_id: String) -> Dictionary:
	if not has_profile(profile_id):
		return {}
	return (PROFILES[profile_id] as Dictionary).duplicate(true)


static func sample_attack(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float = 1.0
) -> Dictionary:
	if attack == null or not has_profile(attack.character_pose_id):
		return {}

	var profile: Dictionary = PROFILES[attack.character_pose_id] as Dictionary
	var phase: Dictionary = get_phase(attack, elapsed, attack_speed)
	var rotation_share: float = clampf(float(profile.get("weapon_rotation_share", 1.0)), 0.0, 1.0)
	var offset_share: float = clampf(float(profile.get("weapon_offset_share", 1.0)), 0.0, 1.0)

	return {
		"profile_id": attack.character_pose_id,
		"phase": str(phase.get("phase", "idle")),
		"phase_weight": float(phase.get("weight", 0.0)),
		"body": _sample_profile_rotation(profile, "body", phase),
		"head": _sample_profile_rotation(profile, "head", phase),
		"left_arm": _sample_profile_rotation(profile, "left_arm", phase),
		"right_arm": _sample_profile_rotation(profile, "right_arm", phase),
		"left_hand_position": _sample_profile_position(profile, "left_hand", phase),
		"right_hand_position": _sample_profile_position(profile, "right_hand", phase),
		"left_hand_rotation": _sample_profile_rotation(profile, "left_hand", phase),
		"right_hand_rotation": _sample_profile_rotation(profile, "right_hand", phase),
		"weapon_rotation_degrees": _sample_attack_rotation(attack, phase) * rotation_share,
		"weapon_offset": _sample_attack_offset(attack, phase) * offset_share,
		"weapon_rotation_share": rotation_share,
		"weapon_offset_share": offset_share,
	}


static func get_phase(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float = 1.0
) -> Dictionary:
	if attack == null:
		return {"phase": "idle", "weight": 0.0}

	var startup: float = maxf(attack.get_startup_duration(attack_speed), 0.001)
	var active: float = maxf(attack.get_active_duration(attack_speed), 0.001)
	var recovery: float = maxf(attack.get_recovery_duration(attack_speed), 0.001)
	var time: float = maxf(elapsed, 0.0)

	if time < startup:
		return {
			"phase": "startup",
			"weight": smoothstep(0.0, 1.0, clampf(time / startup, 0.0, 1.0)),
		}

	if time < startup + active:
		var active_weight: float = clampf((time - startup) / active, 0.0, 1.0)
		return {
			"phase": "active",
			"weight": 1.0 - pow(1.0 - active_weight, 3.0),
		}

	var recovery_weight: float = clampf(
		(time - startup - active) / recovery,
		0.0,
		1.0
	)
	return {
		"phase": "recovery",
		"weight": smoothstep(0.0, 1.0, recovery_weight),
	}


static func validate_profiles() -> Array[String]:
	var failures: Array[String] = []
	for profile_id_variant: Variant in PROFILES.keys():
		var profile_id: String = str(profile_id_variant)
		var profile: Dictionary = PROFILES[profile_id_variant] as Dictionary
		if profile_id.strip_edges() == "":
			failures.append("weapon character pose has an empty id")
		for field_name: String in [
			"windup_body_rotation_degrees",
			"strike_body_rotation_degrees",
			"windup_right_arm_rotation_degrees",
			"strike_right_arm_rotation_degrees",
		]:
			var value: Variant = profile.get(field_name, null)
			if not value is Vector3 or not (value as Vector3).is_finite():
				failures.append(profile_id + " has invalid " + field_name)
	return failures


static func _sample_profile_rotation(
	profile: Dictionary,
	part_id: String,
	phase: Dictionary
) -> Vector3:
	var windup_degrees: Vector3 = profile.get(
		"windup_" + part_id + "_rotation_degrees",
		Vector3.ZERO
	)
	var strike_degrees: Vector3 = profile.get(
		"strike_" + part_id + "_rotation_degrees",
		Vector3.ZERO
	)
	var recovery_degrees: Vector3 = profile.get(
		"recovery_" + part_id + "_rotation_degrees",
		Vector3.ZERO
	)
	return _degrees_to_radians(
		_sample_vector(Vector3.ZERO, windup_degrees, strike_degrees, recovery_degrees, phase)
	)


static func _sample_profile_position(
	profile: Dictionary,
	part_id: String,
	phase: Dictionary
) -> Vector3:
	var windup: Vector3 = profile.get("windup_" + part_id + "_position", Vector3.ZERO)
	var strike: Vector3 = profile.get("strike_" + part_id + "_position", Vector3.ZERO)
	var recovery: Vector3 = profile.get("recovery_" + part_id + "_position", Vector3.ZERO)
	return _sample_vector(Vector3.ZERO, windup, strike, recovery, phase)


static func _sample_attack_rotation(
	attack: WeaponAttackDefinition,
	phase: Dictionary
) -> Vector3:
	return _sample_vector(
		Vector3.ZERO,
		attack.windup_rotation_degrees,
		attack.strike_rotation_degrees,
		attack.recovery_rotation_degrees,
		phase
	)


static func _sample_attack_offset(
	attack: WeaponAttackDefinition,
	phase: Dictionary
) -> Vector3:
	return _sample_vector(
		Vector3.ZERO,
		attack.windup_offset,
		attack.strike_offset,
		attack.recovery_offset,
		phase
	)


static func _sample_vector(
	neutral: Vector3,
	windup: Vector3,
	strike: Vector3,
	recovery: Vector3,
	phase: Dictionary
) -> Vector3:
	var weight: float = clampf(float(phase.get("weight", 0.0)), 0.0, 1.0)
	match str(phase.get("phase", "idle")):
		"startup":
			return neutral.lerp(windup, weight)
		"active":
			return windup.lerp(strike, weight)
		"recovery":
			return strike.lerp(recovery, weight)
		_:
			return neutral


static func _degrees_to_radians(degrees: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees.x),
		deg_to_rad(degrees.y),
		deg_to_rad(degrees.z)
	)
