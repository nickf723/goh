extends RefCounted
class_name WeaponClassMotionCatalog

# Development fallback body language for weapon classes that do not yet own
# hand-authored per-attack animation profiles. Authored attack pose and footwork
# ids always win. These signatures make the combat mannequin communicate weight,
# stance, reach, and rhythm while final animation assets remain swappable.

const PROFILE_PREFIX: String = "class_motion_"

const SIGNATURES: Dictionary = {
	"sword": {
		"name": "Balanced Blade",
		"windup_body": Vector3(-5.0, -24.0, 4.0),
		"strike_body": Vector3(-8.0, 34.0, -4.0),
		"windup_left_arm": Vector3(-18.0, 10.0, -34.0),
		"strike_left_arm": Vector3(12.0, -8.0, 28.0),
		"windup_right_arm": Vector3(32.0, -12.0, 48.0),
		"strike_right_arm": Vector3(-78.0, 16.0, -26.0),
		"hand_windup": Vector3(0.02, 0.03, 0.04),
		"hand_strike": Vector3(-0.04, 0.02, -0.10),
		"foot_light": "sword_cut_right",
		"foot_heavy": "sword_overhead",
		"weapon_rotation_share": 0.28,
		"weapon_offset_share": 0.36,
	},
	"lance": {
		"name": "Driving Point",
		"windup_body": Vector3(2.0, -8.0, 0.0),
		"strike_body": Vector3(-15.0, 6.0, 0.0),
		"windup_left_arm": Vector3(-36.0, 5.0, -18.0),
		"strike_left_arm": Vector3(-62.0, -2.0, -8.0),
		"windup_right_arm": Vector3(-28.0, -4.0, 18.0),
		"strike_right_arm": Vector3(-104.0, 1.0, -5.0),
		"hand_windup": Vector3(0.0, 0.0, 0.08),
		"hand_strike": Vector3(0.0, 0.01, -0.24),
		"foot_light": "sword_thrust",
		"foot_heavy": "sword_thrust_heavy",
		"weapon_rotation_share": 0.08,
		"weapon_offset_share": 0.22,
		"two_handed": true,
	},
	"axe": {
		"name": "Committed Hew",
		"windup_body": Vector3(8.0, -38.0, 8.0),
		"strike_body": Vector3(-17.0, 48.0, -8.0),
		"windup_left_arm": Vector3(-22.0, 12.0, -48.0),
		"strike_left_arm": Vector3(20.0, -9.0, 34.0),
		"windup_right_arm": Vector3(48.0, -20.0, 92.0),
		"strike_right_arm": Vector3(-118.0, 18.0, -42.0),
		"hand_windup": Vector3(0.04, 0.06, 0.08),
		"hand_strike": Vector3(-0.05, -0.01, -0.14),
		"foot_light": "sword_rising_right",
		"foot_heavy": "sword_overhead",
		"weapon_rotation_share": 0.36,
		"weapon_offset_share": 0.40,
	},
	"bow": {
		"name": "Side-On Archer",
		"windup_body": Vector3(-2.0, -58.0, 0.0),
		"strike_body": Vector3(-4.0, -44.0, 0.0),
		"windup_left_arm": Vector3(-84.0, -10.0, -4.0),
		"strike_left_arm": Vector3(-92.0, -6.0, -2.0),
		"windup_right_arm": Vector3(-38.0, 48.0, 54.0),
		"strike_right_arm": Vector3(-70.0, 14.0, 22.0),
		"hand_windup": Vector3(0.06, 0.02, 0.06),
		"hand_strike": Vector3(-0.02, 0.01, -0.08),
		"foot_light": "sword_thrust",
		"foot_heavy": "sword_thrust_heavy",
		"weapon_rotation_share": 0.12,
		"weapon_offset_share": 0.22,
		"two_handed": true,
	},
	"hammer": {
		"name": "Planted Maul",
		"windup_body": Vector3(15.0, -10.0, 0.0),
		"strike_body": Vector3(-28.0, 8.0, 0.0),
		"windup_left_arm": Vector3(12.0, -8.0, 126.0),
		"strike_left_arm": Vector3(-46.0, 4.0, 30.0),
		"windup_right_arm": Vector3(18.0, 8.0, 142.0),
		"strike_right_arm": Vector3(-58.0, -5.0, 18.0),
		"hand_windup": Vector3(0.0, 0.12, 0.03),
		"hand_strike": Vector3(0.0, -0.04, -0.15),
		"foot_light": "sword_overhead",
		"foot_heavy": "sword_overhead",
		"weapon_rotation_share": 0.24,
		"weapon_offset_share": 0.34,
		"two_handed": true,
		"heavy_scale": 1.25,
	},
	"mace": {
		"name": "Shoulder Crusher",
		"windup_body": Vector3(-3.0, -30.0, 7.0),
		"strike_body": Vector3(-12.0, 40.0, -7.0),
		"windup_left_arm": Vector3(-10.0, 8.0, -26.0),
		"strike_left_arm": Vector3(16.0, -8.0, 26.0),
		"windup_right_arm": Vector3(36.0, -18.0, 72.0),
		"strike_right_arm": Vector3(-94.0, 18.0, -34.0),
		"hand_windup": Vector3(0.03, 0.04, 0.04),
		"hand_strike": Vector3(-0.04, 0.01, -0.11),
		"foot_light": "sword_cut_right",
		"foot_heavy": "sword_overhead",
		"weapon_rotation_share": 0.34,
		"weapon_offset_share": 0.38,
	},
	"daggers": {
		"name": "Low Twin Fangs",
		"windup_body": Vector3(-10.0, -14.0, 4.0),
		"strike_body": Vector3(-18.0, 17.0, -4.0),
		"windup_left_arm": Vector3(-52.0, 16.0, -22.0),
		"strike_left_arm": Vector3(-94.0, -8.0, 10.0),
		"windup_right_arm": Vector3(-44.0, -16.0, 24.0),
		"strike_right_arm": Vector3(-102.0, 8.0, -10.0),
		"hand_windup": Vector3(0.02, -0.02, 0.04),
		"hand_strike": Vector3(0.0, 0.0, -0.20),
		"foot_light": "sword_thrust",
		"foot_heavy": "sword_rising_heavy",
		"weapon_rotation_share": 0.12,
		"weapon_offset_share": 0.24,
		"heavy_scale": 1.10,
	},
	"whip": {
		"name": "Delayed Crack",
		"windup_body": Vector3(-4.0, -56.0, 9.0),
		"strike_body": Vector3(-6.0, 82.0, -10.0),
		"windup_left_arm": Vector3(-18.0, 12.0, -42.0),
		"strike_left_arm": Vector3(14.0, -12.0, 44.0),
		"windup_right_arm": Vector3(20.0, -24.0, 76.0),
		"strike_right_arm": Vector3(-106.0, 28.0, -52.0),
		"hand_windup": Vector3(0.05, 0.04, 0.06),
		"hand_strike": Vector3(-0.08, 0.03, -0.15),
		"foot_light": "sword_spin_right",
		"foot_heavy": "sword_cleave_left",
		"weapon_rotation_share": 0.50,
		"weapon_offset_share": 0.44,
	},
	"chains": {
		"name": "Tension Orbit",
		"windup_body": Vector3(-5.0, -68.0, 10.0),
		"strike_body": Vector3(-9.0, 104.0, -11.0),
		"windup_left_arm": Vector3(-28.0, 16.0, -60.0),
		"strike_left_arm": Vector3(24.0, -14.0, 62.0),
		"windup_right_arm": Vector3(14.0, -22.0, 74.0),
		"strike_right_arm": Vector3(-104.0, 30.0, -54.0),
		"hand_windup": Vector3(0.05, 0.05, 0.08),
		"hand_strike": Vector3(-0.09, 0.04, -0.18),
		"foot_light": "sword_spin_right",
		"foot_heavy": "sword_orbit",
		"weapon_rotation_share": 0.56,
		"weapon_offset_share": 0.46,
	},
	"gauntlets": {
		"name": "Hip-Driven Pressure",
		"windup_body": Vector3(-8.0, -18.0, 4.0),
		"strike_body": Vector3(-16.0, 22.0, -4.0),
		"windup_left_arm": Vector3(-42.0, 12.0, -28.0),
		"strike_left_arm": Vector3(-86.0, -10.0, 8.0),
		"windup_right_arm": Vector3(-32.0, -12.0, 32.0),
		"strike_right_arm": Vector3(-108.0, 8.0, -6.0),
		"hand_windup": Vector3(0.02, 0.0, 0.03),
		"hand_strike": Vector3(0.0, 0.0, -0.22),
		"foot_light": "sword_thrust",
		"foot_heavy": "sword_rising_heavy",
		"weapon_rotation_share": 0.04,
		"weapon_offset_share": 0.12,
		"heavy_scale": 1.12,
	},
	"flail": {
		"name": "Stored Orbit",
		"windup_body": Vector3(-3.0, -62.0, 8.0),
		"strike_body": Vector3(-10.0, 96.0, -9.0),
		"windup_left_arm": Vector3(-18.0, 12.0, -44.0),
		"strike_left_arm": Vector3(18.0, -10.0, 46.0),
		"windup_right_arm": Vector3(24.0, -18.0, 78.0),
		"strike_right_arm": Vector3(-100.0, 24.0, -46.0),
		"hand_windup": Vector3(0.05, 0.04, 0.06),
		"hand_strike": Vector3(-0.07, 0.02, -0.14),
		"foot_light": "sword_spin_right",
		"foot_heavy": "sword_orbit",
		"weapon_rotation_share": 0.50,
		"weapon_offset_share": 0.42,
	},
	"halberd": {
		"name": "Polearm Pivot",
		"windup_body": Vector3(2.0, -42.0, 5.0),
		"strike_body": Vector3(-12.0, 56.0, -5.0),
		"windup_left_arm": Vector3(-42.0, 10.0, -28.0),
		"strike_left_arm": Vector3(-66.0, -6.0, 18.0),
		"windup_right_arm": Vector3(-26.0, -12.0, 42.0),
		"strike_right_arm": Vector3(-92.0, 12.0, -22.0),
		"hand_windup": Vector3(0.03, 0.03, 0.08),
		"hand_strike": Vector3(-0.04, 0.01, -0.18),
		"foot_light": "sword_cut_right",
		"foot_heavy": "sword_cleave_left",
		"weapon_rotation_share": 0.34,
		"weapon_offset_share": 0.34,
		"two_handed": true,
	},
	"boomerang": {
		"name": "Throwing Coil",
		"windup_body": Vector3(-2.0, -48.0, 7.0),
		"strike_body": Vector3(-6.0, 38.0, -6.0),
		"windup_left_arm": Vector3(-16.0, 10.0, -32.0),
		"strike_left_arm": Vector3(8.0, -8.0, 22.0),
		"windup_right_arm": Vector3(18.0, -32.0, 88.0),
		"strike_right_arm": Vector3(-112.0, 12.0, -18.0),
		"hand_windup": Vector3(0.05, 0.05, 0.08),
		"hand_strike": Vector3(-0.02, 0.02, -0.18),
		"foot_light": "sword_cut_right",
		"foot_heavy": "sword_thrust_heavy",
		"weapon_rotation_share": 0.18,
		"weapon_offset_share": 0.28,
	},
	"scythe": {
		"name": "Low Reaping Arc",
		"windup_body": Vector3(8.0, -64.0, 10.0),
		"strike_body": Vector3(-14.0, 92.0, -11.0),
		"windup_left_arm": Vector3(-36.0, 12.0, -46.0),
		"strike_left_arm": Vector3(-58.0, -10.0, 36.0),
		"windup_right_arm": Vector3(6.0, -20.0, 68.0),
		"strike_right_arm": Vector3(-96.0, 24.0, -44.0),
		"hand_windup": Vector3(0.04, -0.03, 0.08),
		"hand_strike": Vector3(-0.08, -0.02, -0.16),
		"foot_light": "sword_spin_right",
		"foot_heavy": "sword_orbit",
		"weapon_rotation_share": 0.48,
		"weapon_offset_share": 0.42,
		"two_handed": true,
	},
	"staff": {
		"name": "Balanced Staff Form",
		"windup_body": Vector3(-4.0, -38.0, 4.0),
		"strike_body": Vector3(-8.0, 48.0, -4.0),
		"windup_left_arm": Vector3(-48.0, 8.0, -24.0),
		"strike_left_arm": Vector3(-62.0, -8.0, 20.0),
		"windup_right_arm": Vector3(-18.0, -10.0, 46.0),
		"strike_right_arm": Vector3(-88.0, 10.0, -26.0),
		"hand_windup": Vector3(0.02, 0.02, 0.08),
		"hand_strike": Vector3(-0.04, 0.01, -0.16),
		"foot_light": "sword_cut_right",
		"foot_heavy": "sword_thrust_heavy",
		"weapon_rotation_share": 0.28,
		"weapon_offset_share": 0.32,
		"two_handed": true,
	},
	"shuriken": {
		"name": "Fast Draw Volley",
		"windup_body": Vector3(-6.0, -28.0, 4.0),
		"strike_body": Vector3(-10.0, 18.0, -3.0),
		"windup_left_arm": Vector3(-34.0, 12.0, -26.0),
		"strike_left_arm": Vector3(-70.0, -8.0, 8.0),
		"windup_right_arm": Vector3(10.0, -24.0, 72.0),
		"strike_right_arm": Vector3(-106.0, 8.0, -14.0),
		"hand_windup": Vector3(0.04, 0.03, 0.05),
		"hand_strike": Vector3(0.0, 0.01, -0.18),
		"foot_light": "sword_thrust",
		"foot_heavy": "sword_thrust_heavy",
		"weapon_rotation_share": 0.10,
		"weapon_offset_share": 0.20,
		"heavy_scale": 1.08,
	},
}


static func get_profile_id(weapon_class: String, input_kind: String) -> String:
	var resolved_class: String = weapon_class.to_lower().strip_edges()
	var resolved_input: String = "heavy" if input_kind == "heavy" else "light"
	if not SIGNATURES.has(resolved_class):
		return ""
	return PROFILE_PREFIX + resolved_class + "_" + resolved_input


static func has_profile(profile_id: String) -> bool:
	var parsed: Dictionary = _parse_profile_id(profile_id)
	return not parsed.is_empty()


static func get_profile(profile_id: String) -> Dictionary:
	var parsed: Dictionary = _parse_profile_id(profile_id)
	if parsed.is_empty():
		return {}
	var weapon_class: String = str(parsed.get("weapon_class", ""))
	var signature: Dictionary = (SIGNATURES[weapon_class] as Dictionary).duplicate(true)
	signature["profile_id"] = profile_id
	signature["weapon_class"] = weapon_class
	signature["input_kind"] = str(parsed.get("input_kind", "light"))
	return signature


static func prepare_attack(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> WeaponAttackDefinition:
	if attack == null:
		return null
	var needs_pose: bool = attack.character_pose_id.strip_edges() == ""
	var needs_footwork: bool = attack.footwork_profile_id.strip_edges() == ""
	if not needs_pose and not needs_footwork:
		return attack
	var resolved: WeaponAttackDefinition = attack.duplicate(true) as WeaponAttackDefinition
	if resolved == null:
		return attack
	var signature: Dictionary = SIGNATURES.get(weapon_class, {}) as Dictionary
	if needs_pose:
		resolved.character_pose_id = get_profile_id(weapon_class, attack.input_kind)
	if needs_footwork and not signature.is_empty():
		resolved.footwork_profile_id = str(
			signature.get(
				"foot_heavy" if attack.input_kind == "heavy" else "foot_light",
				""
			)
		)
	return resolved


static func sample_attack(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float = 1.0
) -> Dictionary:
	if attack == null:
		return {}
	var profile: Dictionary = get_profile(attack.character_pose_id)
	if profile.is_empty():
		return {}
	var phase: Dictionary = _get_phase(attack, elapsed, attack_speed)
	var heavy_scale: float = (
		float(profile.get("heavy_scale", 1.18))
		if attack.input_kind == "heavy"
		else 1.0
	)
	var rotation_share: float = clampf(
		float(profile.get("weapon_rotation_share", 0.3)),
		0.0,
		1.0
	)
	var offset_share: float = clampf(
		float(profile.get("weapon_offset_share", 0.35)),
		0.0,
		1.0
	)
	var windup_body: Vector3 = profile.get("windup_body", Vector3.ZERO) * heavy_scale
	var strike_body: Vector3 = profile.get("strike_body", Vector3.ZERO) * heavy_scale
	var windup_left_arm: Vector3 = profile.get("windup_left_arm", Vector3.ZERO) * heavy_scale
	var strike_left_arm: Vector3 = profile.get("strike_left_arm", Vector3.ZERO) * heavy_scale
	var windup_right_arm: Vector3 = profile.get("windup_right_arm", Vector3.ZERO) * heavy_scale
	var strike_right_arm: Vector3 = profile.get("strike_right_arm", Vector3.ZERO) * heavy_scale
	var hand_windup: Vector3 = profile.get("hand_windup", Vector3.ZERO) * heavy_scale
	var hand_strike: Vector3 = profile.get("hand_strike", Vector3.ZERO) * heavy_scale
	var body_degrees: Vector3 = _sample_vector(
		Vector3.ZERO,
		windup_body,
		strike_body,
		Vector3.ZERO,
		phase
	)
	var left_arm_degrees: Vector3 = _sample_vector(
		Vector3.ZERO,
		windup_left_arm,
		strike_left_arm,
		Vector3.ZERO,
		phase
	)
	var right_arm_degrees: Vector3 = _sample_vector(
		Vector3.ZERO,
		windup_right_arm,
		strike_right_arm,
		Vector3.ZERO,
		phase
	)
	var head_degrees := Vector3(
		body_degrees.x * 0.18,
		-body_degrees.y * 0.28,
		-body_degrees.z * 0.12
	)
	var support_weight: float = 0.0
	if bool(profile.get("two_handed", false)):
		support_weight = 0.45 + 0.45 * float(phase.get("weight", 0.0))
	return {
		"profile_id": attack.character_pose_id,
		"phase": str(phase.get("phase", "idle")),
		"phase_weight": float(phase.get("weight", 0.0)),
		"body": _degrees_to_radians(body_degrees),
		"head": _degrees_to_radians(head_degrees),
		"left_arm": _degrees_to_radians(left_arm_degrees),
		"right_arm": _degrees_to_radians(right_arm_degrees),
		"left_hand_position": Vector3.ZERO,
		"right_hand_position": _sample_vector(
			Vector3.ZERO,
			hand_windup,
			hand_strike,
			Vector3.ZERO,
			phase
		),
		"left_hand_rotation": Vector3.ZERO,
		"right_hand_rotation": Vector3.ZERO,
		"weapon_rotation_degrees": _sample_vector(
			Vector3.ZERO,
			attack.windup_rotation_degrees,
			attack.strike_rotation_degrees,
			attack.recovery_rotation_degrees,
			phase
		) * rotation_share,
		"weapon_offset": _sample_vector(
			Vector3.ZERO,
			attack.windup_offset,
			attack.strike_offset,
			attack.recovery_offset,
			phase
		) * offset_share,
		"weapon_rotation_share": rotation_share,
		"weapon_offset_share": offset_share,
		"two_handed": bool(profile.get("two_handed", false)),
		"support_hand_weight": support_weight,
		"support_grip_position": Vector3(0.12, 0.0, -0.58),
		"support_grip_rotation": Vector3.ZERO,
		"fallback_class_motion": true,
	}


static func validate_profiles() -> Array[String]:
	var failures: Array[String] = []
	for weapon_class_variant: Variant in SIGNATURES.keys():
		var weapon_class: String = str(weapon_class_variant)
		var signature: Dictionary = SIGNATURES[weapon_class_variant] as Dictionary
		for field_name: String in [
			"windup_body", "strike_body",
			"windup_left_arm", "strike_left_arm",
			"windup_right_arm", "strike_right_arm",
			"hand_windup", "hand_strike",
		]:
			var value: Variant = signature.get(field_name, null)
			if not value is Vector3 or not (value as Vector3).is_finite():
				failures.append(weapon_class + " has invalid class motion " + field_name)
		for input_kind: String in ["light", "heavy"]:
			if not has_profile(get_profile_id(weapon_class, input_kind)):
				failures.append(weapon_class + " cannot resolve " + input_kind + " class motion")
	return failures


static func _parse_profile_id(profile_id: String) -> Dictionary:
	if not profile_id.begins_with(PROFILE_PREFIX):
		return {}
	var remainder: String = profile_id.trim_prefix(PROFILE_PREFIX)
	var split_index: int = remainder.rfind("_")
	if split_index <= 0:
		return {}
	var weapon_class: String = remainder.substr(0, split_index)
	var input_kind: String = remainder.substr(split_index + 1)
	if input_kind not in ["light", "heavy"] or not SIGNATURES.has(weapon_class):
		return {}
	return {"weapon_class": weapon_class, "input_kind": input_kind}


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
