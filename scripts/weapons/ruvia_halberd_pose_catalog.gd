extends RefCounted
class_name RuviaHalberdPoseCatalog

# Ruvia's halberd performance is authored around a rear-hand drive and a front-hand
# guide. The weapon remains attached to the right hand, while the support-grip
# target lets the left hand slide, brace, and redirect the shaft during each form.
const PROFILES: Dictionary = {
	"ruvia_halberd_cinder_sweep": {
		"windup_body_rotation_degrees": Vector3(-5.0, -38.0, 5.0),
		"strike_body_rotation_degrees": Vector3(-10.0, 54.0, -6.0),
		"windup_head_rotation_degrees": Vector3(0.0, 12.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, -18.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-38.0, 18.0, -56.0),
		"strike_left_arm_rotation_degrees": Vector3(-52.0, -22.0, 38.0),
		"windup_right_arm_rotation_degrees": Vector3(24.0, -20.0, 70.0),
		"strike_right_arm_rotation_degrees": Vector3(-94.0, 26.0, -38.0),
		"windup_right_hand_position": Vector3(0.06, 0.02, 0.08),
		"strike_right_hand_position": Vector3(-0.09, 0.01, -0.16),
		"windup_right_hand_rotation_degrees": Vector3(8.0, -14.0, -20.0),
		"strike_right_hand_rotation_degrees": Vector3(-10.0, 18.0, 26.0),
		"weapon_rotation_share": 0.58,
		"weapon_offset_share": 0.42,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.6),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.92),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.7),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.62),
		"windup_support_grip_rotation_degrees": Vector3(0.0, 0.0, -12.0),
		"strike_support_grip_rotation_degrees": Vector3(0.0, 0.0, 12.0),
	},
	"ruvia_halberd_backdraft_return": {
		"windup_body_rotation_degrees": Vector3(-6.0, 46.0, -5.0),
		"strike_body_rotation_degrees": Vector3(-11.0, -58.0, 6.0),
		"windup_head_rotation_degrees": Vector3(0.0, -15.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, 19.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-48.0, -18.0, 42.0),
		"strike_left_arm_rotation_degrees": Vector3(-36.0, 22.0, -58.0),
		"windup_right_arm_rotation_degrees": Vector3(-86.0, 24.0, -36.0),
		"strike_right_arm_rotation_degrees": Vector3(-102.0, -28.0, 42.0),
		"windup_right_hand_position": Vector3(-0.08, 0.01, -0.12),
		"strike_right_hand_position": Vector3(0.09, 0.02, -0.17),
		"windup_right_hand_rotation_degrees": Vector3(-8.0, 16.0, 22.0),
		"strike_right_hand_rotation_degrees": Vector3(10.0, -18.0, -28.0),
		"weapon_rotation_share": 0.6,
		"weapon_offset_share": 0.42,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.62),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.74),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.94),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.64),
		"windup_support_grip_rotation_degrees": Vector3(0.0, 0.0, 10.0),
		"strike_support_grip_rotation_degrees": Vector3(0.0, 0.0, -14.0),
	},
	"ruvia_halberd_haft_check": {
		"windup_body_rotation_degrees": Vector3(-4.0, 20.0, -3.0),
		"strike_body_rotation_degrees": Vector3(-9.0, -30.0, 4.0),
		"windup_head_rotation_degrees": Vector3(0.0, -7.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, 10.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-30.0, -8.0, 28.0),
		"strike_left_arm_rotation_degrees": Vector3(-54.0, 12.0, -18.0),
		"windup_right_arm_rotation_degrees": Vector3(-42.0, 12.0, -18.0),
		"strike_right_arm_rotation_degrees": Vector3(-78.0, -16.0, 28.0),
		"windup_right_hand_position": Vector3(-0.02, 0.0, -0.02),
		"strike_right_hand_position": Vector3(0.07, 0.0, -0.12),
		"windup_right_hand_rotation_degrees": Vector3(-4.0, 8.0, 10.0),
		"strike_right_hand_rotation_degrees": Vector3(6.0, -10.0, -14.0),
		"weapon_rotation_share": 0.7,
		"weapon_offset_share": 0.3,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.46),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.42),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.34),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.48),
		"windup_support_grip_rotation_degrees": Vector3(0.0, 0.0, 6.0),
		"strike_support_grip_rotation_degrees": Vector3(0.0, 0.0, -8.0),
	},
	"ruvia_halberd_rising_brand": {
		"windup_body_rotation_degrees": Vector3(10.0, -30.0, 8.0),
		"strike_body_rotation_degrees": Vector3(-15.0, 40.0, -8.0),
		"windup_head_rotation_degrees": Vector3(7.0, 10.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-8.0, -13.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-44.0, 12.0, -48.0),
		"strike_left_arm_rotation_degrees": Vector3(-28.0, -14.0, 58.0),
		"windup_right_arm_rotation_degrees": Vector3(48.0, -18.0, 76.0),
		"strike_right_arm_rotation_degrees": Vector3(-130.0, 16.0, -48.0),
		"windup_right_hand_position": Vector3(0.05, -0.05, 0.09),
		"strike_right_hand_position": Vector3(-0.07, 0.14, -0.17),
		"windup_right_hand_rotation_degrees": Vector3(15.0, -12.0, -26.0),
		"strike_right_hand_rotation_degrees": Vector3(-22.0, 14.0, 34.0),
		"weapon_rotation_share": 0.54,
		"weapon_offset_share": 0.46,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.66),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.9),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.68),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.64),
		"windup_support_grip_rotation_degrees": Vector3(-8.0, 0.0, -12.0),
		"strike_support_grip_rotation_degrees": Vector3(10.0, 0.0, 14.0),
	},
	"ruvia_halberd_ember_wheel": {
		"windup_body_rotation_degrees": Vector3(-6.0, -70.0, 10.0),
		"strike_body_rotation_degrees": Vector3(-12.0, 120.0, -12.0),
		"windup_head_rotation_degrees": Vector3(0.0, 22.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, -30.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-54.0, 18.0, -68.0),
		"strike_left_arm_rotation_degrees": Vector3(-30.0, -20.0, 72.0),
		"windup_right_arm_rotation_degrees": Vector3(20.0, -22.0, 82.0),
		"strike_right_arm_rotation_degrees": Vector3(-112.0, 30.0, -58.0),
		"windup_right_hand_position": Vector3(0.07, 0.05, 0.1),
		"strike_right_hand_position": Vector3(-0.1, 0.05, -0.19),
		"windup_right_hand_rotation_degrees": Vector3(12.0, -18.0, -28.0),
		"strike_right_hand_rotation_degrees": Vector3(-15.0, 22.0, 36.0),
		"weapon_rotation_share": 0.74,
		"weapon_offset_share": 0.48,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.64),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.84),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.58),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.66),
		"windup_support_grip_rotation_degrees": Vector3(0.0, 0.0, -18.0),
		"strike_support_grip_rotation_degrees": Vector3(0.0, 0.0, 20.0),
		"support_hand_recovery_weight": 0.82,
	},
	"ruvia_halberd_furnace_drop": {
		"windup_body_rotation_degrees": Vector3(12.0, -8.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-22.0, 10.0, 0.0),
		"windup_head_rotation_degrees": Vector3(9.0, 3.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-10.0, -4.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-18.0, 8.0, -118.0),
		"strike_left_arm_rotation_degrees": Vector3(-62.0, -6.0, 24.0),
		"windup_right_arm_rotation_degrees": Vector3(8.0, -10.0, 154.0),
		"strike_right_arm_rotation_degrees": Vector3(-74.0, 8.0, 18.0),
		"windup_right_hand_position": Vector3(-0.04, 0.15, 0.04),
		"strike_right_hand_position": Vector3(0.01, -0.04, -0.18),
		"windup_right_hand_rotation_degrees": Vector3(16.0, 0.0, -20.0),
		"strike_right_hand_rotation_degrees": Vector3(-18.0, 0.0, 14.0),
		"weapon_rotation_share": 0.46,
		"weapon_offset_share": 0.38,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.7),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.98),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.78),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.7),
		"windup_support_grip_rotation_degrees": Vector3(-14.0, 0.0, -4.0),
		"strike_support_grip_rotation_degrees": Vector3(12.0, 0.0, 4.0),
	},
	"ruvia_halberd_scorching_thrust": {
		"windup_body_rotation_degrees": Vector3(-5.0, -14.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-18.0, 12.0, 0.0),
		"windup_head_rotation_degrees": Vector3(0.0, 5.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-5.0, -4.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-38.0, 8.0, -52.0),
		"strike_left_arm_rotation_degrees": Vector3(-64.0, -5.0, -20.0),
		"windup_right_arm_rotation_degrees": Vector3(-38.0, -5.0, 22.0),
		"strike_right_arm_rotation_degrees": Vector3(-112.0, 0.0, -8.0),
		"windup_right_hand_position": Vector3(0.0, 0.0, 0.08),
		"strike_right_hand_position": Vector3(0.0, 0.02, -0.3),
		"windup_right_hand_rotation_degrees": Vector3(0.0, -6.0, -6.0),
		"strike_right_hand_rotation_degrees": Vector3(-6.0, 6.0, 6.0),
		"weapon_rotation_share": 0.08,
		"weapon_offset_share": 0.68,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.72),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.98),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.48),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.72),
		"windup_support_grip_rotation_degrees": Vector3(0.0, 0.0, -4.0),
		"strike_support_grip_rotation_degrees": Vector3(0.0, 0.0, 4.0),
	},
	"ruvia_halberd_reaping_hook": {
		"windup_body_rotation_degrees": Vector3(8.0, -34.0, 8.0),
		"strike_body_rotation_degrees": Vector3(-16.0, 44.0, -8.0),
		"windup_head_rotation_degrees": Vector3(6.0, 11.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-8.0, -14.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-52.0, 12.0, -58.0),
		"strike_left_arm_rotation_degrees": Vector3(-34.0, -14.0, 46.0),
		"windup_right_arm_rotation_degrees": Vector3(54.0, -20.0, 68.0),
		"strike_right_arm_rotation_degrees": Vector3(-126.0, 18.0, -42.0),
		"windup_right_hand_position": Vector3(0.05, -0.04, 0.08),
		"strike_right_hand_position": Vector3(-0.08, 0.11, -0.18),
		"windup_right_hand_rotation_degrees": Vector3(14.0, -12.0, -22.0),
		"strike_right_hand_rotation_degrees": Vector3(-18.0, 14.0, 28.0),
		"weapon_rotation_share": 0.6,
		"weapon_offset_share": 0.45,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.68),
		"windup_support_grip_position": Vector3(0.12, 0.0, -0.92),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.62),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.7),
		"windup_support_grip_rotation_degrees": Vector3(-8.0, 0.0, -14.0),
		"strike_support_grip_rotation_degrees": Vector3(10.0, 0.0, 16.0),
	},
	"ruvia_halberd_wildfire_cleave": {
		"windup_body_rotation_degrees": Vector3(-8.0, 58.0, -8.0),
		"strike_body_rotation_degrees": Vector3(-16.0, -86.0, 9.0),
		"windup_head_rotation_degrees": Vector3(0.0, -20.0, 0.0),
		"strike_head_rotation_degrees": Vector3(0.0, 26.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-42.0, -18.0, 52.0),
		"strike_left_arm_rotation_degrees": Vector3(-58.0, 22.0, -66.0),
		"windup_right_arm_rotation_degrees": Vector3(-70.0, 26.0, -42.0),
		"strike_right_arm_rotation_degrees": Vector3(-108.0, -30.0, 56.0),
		"windup_right_hand_position": Vector3(-0.08, 0.04, -0.08),
		"strike_right_hand_position": Vector3(0.1, 0.02, -0.2),
		"windup_right_hand_rotation_degrees": Vector3(-10.0, 18.0, 24.0),
		"strike_right_hand_rotation_degrees": Vector3(14.0, -22.0, -34.0),
		"weapon_rotation_share": 0.68,
		"weapon_offset_share": 0.5,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.7),
		"windup_support_grip_position": Vector3(0.12, 0.0, -1.0),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.72),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.68),
		"windup_support_grip_rotation_degrees": Vector3(0.0, 0.0, 16.0),
		"strike_support_grip_rotation_degrees": Vector3(0.0, 0.0, -18.0),
	},
	"ruvia_halberd_solar_descent": {
		"windup_body_rotation_degrees": Vector3(15.0, -20.0, 4.0),
		"strike_body_rotation_degrees": Vector3(-26.0, 32.0, -5.0),
		"windup_head_rotation_degrees": Vector3(11.0, 7.0, 0.0),
		"strike_head_rotation_degrees": Vector3(-12.0, -10.0, 0.0),
		"windup_left_arm_rotation_degrees": Vector3(-24.0, 12.0, -124.0),
		"strike_left_arm_rotation_degrees": Vector3(-68.0, -10.0, 28.0),
		"windup_right_arm_rotation_degrees": Vector3(14.0, -14.0, 160.0),
		"strike_right_arm_rotation_degrees": Vector3(-82.0, 12.0, 20.0),
		"windup_right_hand_position": Vector3(-0.05, 0.17, 0.05),
		"strike_right_hand_position": Vector3(0.02, -0.06, -0.22),
		"windup_right_hand_rotation_degrees": Vector3(18.0, -4.0, -24.0),
		"strike_right_hand_rotation_degrees": Vector3(-22.0, 4.0, 18.0),
		"weapon_rotation_share": 0.52,
		"weapon_offset_share": 0.44,
		"neutral_support_grip_position": Vector3(0.12, 0.0, -0.72),
		"windup_support_grip_position": Vector3(0.12, 0.0, -1.02),
		"strike_support_grip_position": Vector3(0.12, 0.0, -0.8),
		"recovery_support_grip_position": Vector3(0.12, 0.0, -0.72),
		"windup_support_grip_rotation_degrees": Vector3(-16.0, 0.0, -6.0),
		"strike_support_grip_rotation_degrees": Vector3(14.0, 0.0, 6.0),
		"support_hand_recovery_weight": 0.86,
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
	var phase: Dictionary = _get_phase(attack, elapsed, attack_speed)
	var rotation_share: float = clampf(
		float(profile.get("weapon_rotation_share", 1.0)),
		0.0,
		1.0
	)
	var offset_share: float = clampf(
		float(profile.get("weapon_offset_share", 1.0)),
		0.0,
		1.0
	)
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
		"two_handed": true,
		"support_grip_position": _sample_support_grip_position(profile, phase),
		"support_grip_rotation": _sample_support_grip_rotation(profile, phase),
		"support_hand_weight": _sample_support_hand_weight(profile, phase),
	}


static func validate_profiles() -> Array[String]:
	var failures: Array[String] = []
	for profile_id_variant: Variant in PROFILES.keys():
		var profile_id: String = str(profile_id_variant)
		var profile: Dictionary = PROFILES[profile_id_variant] as Dictionary
		if profile_id.strip_edges() == "":
			failures.append("Ruvia halberd pose has an empty id")
		for field_name: String in [
			"windup_body_rotation_degrees",
			"strike_body_rotation_degrees",
			"windup_left_arm_rotation_degrees",
			"strike_left_arm_rotation_degrees",
			"windup_right_arm_rotation_degrees",
			"strike_right_arm_rotation_degrees",
			"neutral_support_grip_position",
			"windup_support_grip_position",
			"strike_support_grip_position",
			"recovery_support_grip_position",
		]:
			var value: Variant = profile.get(field_name, null)
			if not value is Vector3 or not (value as Vector3).is_finite():
				failures.append(profile_id + " has invalid " + field_name)
		var neutral_grip: Vector3 = profile.get(
			"neutral_support_grip_position",
			Vector3.ZERO
		)
		if neutral_grip.z > -0.2 or neutral_grip.z < -1.25:
			failures.append(profile_id + " support grip is outside the authored shaft")
	return failures


static func _get_phase(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> Dictionary:
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


static func _sample_profile_rotation(
	profile: Dictionary,
	part_id: String,
	phase: Dictionary
) -> Vector3:
	var windup: Vector3 = profile.get(
		"windup_" + part_id + "_rotation_degrees",
		Vector3.ZERO
	)
	var strike: Vector3 = profile.get(
		"strike_" + part_id + "_rotation_degrees",
		Vector3.ZERO
	)
	var recovery: Vector3 = profile.get(
		"recovery_" + part_id + "_rotation_degrees",
		Vector3.ZERO
	)
	return _degrees_to_radians(
		_sample_vector(Vector3.ZERO, windup, strike, recovery, phase)
	)


static func _sample_profile_position(
	profile: Dictionary,
	part_id: String,
	phase: Dictionary
) -> Vector3:
	var windup: Vector3 = profile.get(
		"windup_" + part_id + "_position",
		Vector3.ZERO
	)
	var strike: Vector3 = profile.get(
		"strike_" + part_id + "_position",
		Vector3.ZERO
	)
	var recovery: Vector3 = profile.get(
		"recovery_" + part_id + "_position",
		Vector3.ZERO
	)
	return _sample_vector(Vector3.ZERO, windup, strike, recovery, phase)


static func _sample_support_grip_position(
	profile: Dictionary,
	phase: Dictionary
) -> Vector3:
	var neutral: Vector3 = profile.get(
		"neutral_support_grip_position",
		Vector3(0.12, 0.0, -0.62)
	)
	var windup: Vector3 = profile.get("windup_support_grip_position", neutral)
	var strike: Vector3 = profile.get("strike_support_grip_position", windup)
	var recovery: Vector3 = profile.get("recovery_support_grip_position", neutral)
	return _sample_vector(neutral, windup, strike, recovery, phase)


static func _sample_support_grip_rotation(
	profile: Dictionary,
	phase: Dictionary
) -> Vector3:
	var neutral: Vector3 = profile.get(
		"neutral_support_grip_rotation_degrees",
		Vector3.ZERO
	)
	var windup: Vector3 = profile.get(
		"windup_support_grip_rotation_degrees",
		neutral
	)
	var strike: Vector3 = profile.get(
		"strike_support_grip_rotation_degrees",
		windup
	)
	var recovery: Vector3 = profile.get(
		"recovery_support_grip_rotation_degrees",
		neutral
	)
	return _degrees_to_radians(
		_sample_vector(neutral, windup, strike, recovery, phase)
	)


static func _sample_support_hand_weight(
	profile: Dictionary,
	phase: Dictionary
) -> float:
	var phase_weight: float = clampf(float(phase.get("weight", 0.0)), 0.0, 1.0)
	var full_weight: float = clampf(float(profile.get("support_hand_weight", 1.0)), 0.0, 1.0)
	var recovery_weight: float = clampf(
		float(profile.get("support_hand_recovery_weight", 0.72)),
		0.0,
		1.0
	)
	match str(phase.get("phase", "idle")):
		"startup":
			return full_weight * phase_weight
		"active":
			return full_weight
		"recovery":
			return lerpf(full_weight, recovery_weight, phase_weight)
		_:
			return 0.0


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
