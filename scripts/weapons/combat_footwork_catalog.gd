extends RefCounted
class_name CombatFootworkCatalog

const PROFILES: Dictionary = {
	"sword_cut_right": {
		"display_name": "Right-Leading Cut",
		"plant_foot": "right",
		"plant_end": 0.18,
		"drive_end": 0.72,
		"plant_speed": 0.32,
		"peak_speed": 1.48,
		"drive_exit_speed": 0.9,
		"settle_speed": 0.2,
		"steering_multiplier": 0.9,
		"windup_root_position": Vector3(0.025, -0.035, 0.018),
		"strike_root_position": Vector3(-0.045, -0.055, -0.055),
		"recovery_root_position": Vector3(-0.012, -0.018, -0.012),
		"windup_root_rotation_degrees": Vector3(0.0, -3.0, 1.5),
		"strike_root_rotation_degrees": Vector3(-1.0, 6.0, -2.5),
		"recovery_root_rotation_degrees": Vector3.ZERO,
		"windup_body_position": Vector3(0.0, -0.018, 0.0),
		"strike_body_position": Vector3(0.0, -0.028, -0.018),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(2.0, -4.0, 1.0),
		"strike_body_rotation_degrees": Vector3(-3.0, 7.0, -1.5),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-10.0, 0.0, -3.0),
		"strike_left_leg_rotation_degrees": Vector3(8.0, 0.0, 2.0),
		"recovery_left_leg_rotation_degrees": Vector3(-2.0, 0.0, -1.0),
		"windup_right_leg_rotation_degrees": Vector3(16.0, 0.0, 4.0),
		"strike_right_leg_rotation_degrees": Vector3(-12.0, 0.0, -3.0),
		"recovery_right_leg_rotation_degrees": Vector3(2.0, 0.0, 1.0),
		"windup_left_leg_position": Vector3(-0.012, -0.012, 0.025),
		"strike_left_leg_position": Vector3(-0.018, -0.018, -0.035),
		"recovery_left_leg_position": Vector3.ZERO,
		"windup_right_leg_position": Vector3(0.016, -0.018, -0.035),
		"strike_right_leg_position": Vector3(0.018, -0.012, 0.035),
		"recovery_right_leg_position": Vector3.ZERO,
	},
	"sword_cut_left": {
		"display_name": "Returning Left Cut",
		"plant_foot": "left",
		"plant_end": 0.17,
		"drive_end": 0.71,
		"plant_speed": 0.3,
		"peak_speed": 1.5,
		"drive_exit_speed": 0.92,
		"settle_speed": 0.2,
		"steering_multiplier": 0.9,
		"windup_root_position": Vector3(-0.025, -0.035, 0.018),
		"strike_root_position": Vector3(0.045, -0.055, -0.055),
		"recovery_root_position": Vector3(0.012, -0.018, -0.012),
		"windup_root_rotation_degrees": Vector3(0.0, 3.0, -1.5),
		"strike_root_rotation_degrees": Vector3(-1.0, -6.0, 2.5),
		"recovery_root_rotation_degrees": Vector3.ZERO,
		"windup_body_position": Vector3(0.0, -0.018, 0.0),
		"strike_body_position": Vector3(0.0, -0.028, -0.018),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(2.0, 4.0, -1.0),
		"strike_body_rotation_degrees": Vector3(-3.0, -7.0, 1.5),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(16.0, 0.0, -4.0),
		"strike_left_leg_rotation_degrees": Vector3(-12.0, 0.0, 3.0),
		"recovery_left_leg_rotation_degrees": Vector3(2.0, 0.0, -1.0),
		"windup_right_leg_rotation_degrees": Vector3(-10.0, 0.0, 3.0),
		"strike_right_leg_rotation_degrees": Vector3(8.0, 0.0, -2.0),
		"recovery_right_leg_rotation_degrees": Vector3(-2.0, 0.0, 1.0),
		"windup_left_leg_position": Vector3(-0.016, -0.018, -0.035),
		"strike_left_leg_position": Vector3(-0.018, -0.012, 0.035),
		"recovery_left_leg_position": Vector3.ZERO,
		"windup_right_leg_position": Vector3(0.012, -0.012, 0.025),
		"strike_right_leg_position": Vector3(0.018, -0.018, -0.035),
		"recovery_right_leg_position": Vector3.ZERO,
	},
	"sword_rising_right": {
		"display_name": "Rising Drive",
		"plant_foot": "right",
		"plant_end": 0.22,
		"drive_end": 0.69,
		"plant_speed": 0.2,
		"peak_speed": 1.62,
		"drive_exit_speed": 0.86,
		"settle_speed": 0.16,
		"steering_multiplier": 0.75,
		"windup_root_position": Vector3(0.025, -0.09, 0.025),
		"strike_root_position": Vector3(-0.028, -0.025, -0.075),
		"recovery_root_position": Vector3(-0.008, -0.018, -0.018),
		"windup_root_rotation_degrees": Vector3(4.0, -2.0, 2.0),
		"strike_root_rotation_degrees": Vector3(-5.0, 5.0, -2.0),
		"recovery_root_rotation_degrees": Vector3.ZERO,
		"windup_body_position": Vector3(0.0, -0.04, 0.02),
		"strike_body_position": Vector3(0.0, 0.018, -0.025),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(7.0, -3.0, 2.0),
		"strike_body_rotation_degrees": Vector3(-8.0, 6.0, -2.5),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-18.0, 0.0, -5.0),
		"strike_left_leg_rotation_degrees": Vector3(14.0, 0.0, 3.0),
		"recovery_left_leg_rotation_degrees": Vector3(-2.0, 0.0, -1.0),
		"windup_right_leg_rotation_degrees": Vector3(24.0, 0.0, 6.0),
		"strike_right_leg_rotation_degrees": Vector3(-18.0, 0.0, -4.0),
		"recovery_right_leg_rotation_degrees": Vector3(3.0, 0.0, 1.0),
		"windup_left_leg_position": Vector3(-0.018, -0.025, 0.04),
		"strike_left_leg_position": Vector3(-0.015, -0.012, -0.035),
		"recovery_left_leg_position": Vector3.ZERO,
		"windup_right_leg_position": Vector3(0.022, -0.03, -0.045),
		"strike_right_leg_position": Vector3(0.018, -0.012, 0.04),
		"recovery_right_leg_position": Vector3.ZERO,
	},
	"sword_spin_right": {
		"display_name": "Circular Pivot",
		"plant_foot": "right",
		"plant_end": 0.2,
		"drive_end": 0.75,
		"plant_speed": 0.34,
		"peak_speed": 1.34,
		"drive_exit_speed": 1.02,
		"settle_speed": 0.28,
		"steering_multiplier": 0.52,
		"windup_root_position": Vector3(0.045, -0.055, 0.02),
		"strike_root_position": Vector3(-0.055, -0.06, -0.045),
		"recovery_root_position": Vector3(-0.012, -0.025, -0.01),
		"windup_root_rotation_degrees": Vector3(0.0, -8.0, 2.5),
		"strike_root_rotation_degrees": Vector3(-2.0, 14.0, -3.0),
		"recovery_root_rotation_degrees": Vector3(0.0, 2.0, 0.0),
		"windup_body_position": Vector3(0.0, -0.025, 0.0),
		"strike_body_position": Vector3(0.0, -0.035, -0.02),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(2.0, -7.0, 2.0),
		"strike_body_rotation_degrees": Vector3(-3.0, 12.0, -2.0),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-12.0, -4.0, -8.0),
		"strike_left_leg_rotation_degrees": Vector3(10.0, 5.0, 8.0),
		"recovery_left_leg_rotation_degrees": Vector3(-2.0, 0.0, -3.0),
		"windup_right_leg_rotation_degrees": Vector3(16.0, 4.0, 8.0),
		"strike_right_leg_rotation_degrees": Vector3(-14.0, -5.0, -8.0),
		"recovery_right_leg_rotation_degrees": Vector3(2.0, 0.0, 3.0),
		"windup_left_leg_position": Vector3(-0.045, -0.02, 0.025),
		"strike_left_leg_position": Vector3(-0.05, -0.02, -0.02),
		"recovery_left_leg_position": Vector3(-0.015, 0.0, 0.0),
		"windup_right_leg_position": Vector3(0.045, -0.02, -0.025),
		"strike_right_leg_position": Vector3(0.05, -0.02, 0.02),
		"recovery_right_leg_position": Vector3(0.015, 0.0, 0.0),
	},
	"sword_thrust": {
		"display_name": "Measured Thrust",
		"plant_foot": "right",
		"plant_end": 0.2,
		"drive_end": 0.66,
		"plant_speed": 0.16,
		"peak_speed": 1.68,
		"drive_exit_speed": 0.82,
		"settle_speed": 0.12,
		"steering_multiplier": 0.45,
		"windup_root_position": Vector3(0.0, -0.055, 0.055),
		"strike_root_position": Vector3(0.0, -0.04, -0.11),
		"recovery_root_position": Vector3(0.0, -0.02, -0.025),
		"windup_root_rotation_degrees": Vector3(1.5, 0.0, 0.0),
		"strike_root_rotation_degrees": Vector3(-4.0, 0.0, 0.0),
		"recovery_root_rotation_degrees": Vector3.ZERO,
		"windup_body_position": Vector3(0.0, -0.025, 0.025),
		"strike_body_position": Vector3(0.0, -0.01, -0.05),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(3.0, 0.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-6.0, 0.0, 0.0),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-16.0, 0.0, -3.0),
		"strike_left_leg_rotation_degrees": Vector3(18.0, 0.0, 2.0),
		"recovery_left_leg_rotation_degrees": Vector3(-2.0, 0.0, -1.0),
		"windup_right_leg_rotation_degrees": Vector3(22.0, 0.0, 4.0),
		"strike_right_leg_rotation_degrees": Vector3(-22.0, 0.0, -3.0),
		"recovery_right_leg_rotation_degrees": Vector3(3.0, 0.0, 1.0),
		"windup_left_leg_position": Vector3(-0.012, -0.02, 0.055),
		"strike_left_leg_position": Vector3(-0.012, -0.012, -0.06),
		"recovery_left_leg_position": Vector3.ZERO,
		"windup_right_leg_position": Vector3(0.015, -0.025, -0.065),
		"strike_right_leg_position": Vector3(0.015, -0.012, 0.065),
		"recovery_right_leg_position": Vector3.ZERO,
	},
	"sword_overhead": {
		"display_name": "Overhead Plant",
		"plant_foot": "both",
		"plant_end": 0.28,
		"drive_end": 0.72,
		"plant_speed": 0.1,
		"peak_speed": 1.58,
		"drive_exit_speed": 0.72,
		"settle_speed": 0.08,
		"steering_multiplier": 0.32,
		"windup_root_position": Vector3(0.0, -0.095, 0.025),
		"strike_root_position": Vector3(0.0, -0.075, -0.055),
		"recovery_root_position": Vector3(0.0, -0.035, -0.012),
		"windup_root_rotation_degrees": Vector3(4.0, 0.0, 0.0),
		"strike_root_rotation_degrees": Vector3(-6.0, 0.0, 0.0),
		"recovery_root_rotation_degrees": Vector3(1.0, 0.0, 0.0),
		"windup_body_position": Vector3(0.0, -0.04, 0.02),
		"strike_body_position": Vector3(0.0, -0.045, -0.03),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(7.0, 0.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-9.0, 0.0, 0.0),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-8.0, 0.0, -7.0),
		"strike_left_leg_rotation_degrees": Vector3(12.0, 0.0, -5.0),
		"recovery_left_leg_rotation_degrees": Vector3(-2.0, 0.0, -2.0),
		"windup_right_leg_rotation_degrees": Vector3(8.0, 0.0, 7.0),
		"strike_right_leg_rotation_degrees": Vector3(-12.0, 0.0, 5.0),
		"recovery_right_leg_rotation_degrees": Vector3(2.0, 0.0, 2.0),
		"windup_left_leg_position": Vector3(-0.04, -0.03, 0.015),
		"strike_left_leg_position": Vector3(-0.045, -0.025, -0.02),
		"recovery_left_leg_position": Vector3(-0.015, 0.0, 0.0),
		"windup_right_leg_position": Vector3(0.04, -0.03, -0.015),
		"strike_right_leg_position": Vector3(0.045, -0.025, 0.02),
		"recovery_right_leg_position": Vector3(0.015, 0.0, 0.0),
	},
	"sword_rising_heavy": {
		"display_name": "Heavy Rising Drive",
		"plant_foot": "right",
		"plant_end": 0.25,
		"drive_end": 0.7,
		"plant_speed": 0.14,
		"peak_speed": 1.72,
		"drive_exit_speed": 0.78,
		"settle_speed": 0.1,
		"steering_multiplier": 0.38,
		"windup_root_position": Vector3(0.035, -0.115, 0.035),
		"strike_root_position": Vector3(-0.035, -0.035, -0.09),
		"recovery_root_position": Vector3(-0.01, -0.028, -0.018),
		"windup_root_rotation_degrees": Vector3(5.0, -3.0, 3.0),
		"strike_root_rotation_degrees": Vector3(-7.0, 6.0, -3.0),
		"recovery_root_rotation_degrees": Vector3.ZERO,
		"windup_body_position": Vector3(0.0, -0.055, 0.025),
		"strike_body_position": Vector3(0.0, 0.022, -0.035),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(9.0, -4.0, 3.0),
		"strike_body_rotation_degrees": Vector3(-11.0, 7.0, -3.0),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-22.0, 0.0, -6.0),
		"strike_left_leg_rotation_degrees": Vector3(17.0, 0.0, 4.0),
		"recovery_left_leg_rotation_degrees": Vector3(-3.0, 0.0, -1.0),
		"windup_right_leg_rotation_degrees": Vector3(28.0, 0.0, 7.0),
		"strike_right_leg_rotation_degrees": Vector3(-22.0, 0.0, -5.0),
		"recovery_right_leg_rotation_degrees": Vector3(4.0, 0.0, 1.0),
		"windup_left_leg_position": Vector3(-0.02, -0.035, 0.05),
		"strike_left_leg_position": Vector3(-0.018, -0.015, -0.045),
		"recovery_left_leg_position": Vector3.ZERO,
		"windup_right_leg_position": Vector3(0.025, -0.04, -0.055),
		"strike_right_leg_position": Vector3(0.02, -0.015, 0.05),
		"recovery_right_leg_position": Vector3.ZERO,
	},
	"sword_cleave_left": {
		"display_name": "Wide Cleave Plant",
		"plant_foot": "left",
		"plant_end": 0.24,
		"drive_end": 0.74,
		"plant_speed": 0.18,
		"peak_speed": 1.46,
		"drive_exit_speed": 0.88,
		"settle_speed": 0.14,
		"steering_multiplier": 0.36,
		"windup_root_position": Vector3(-0.055, -0.085, 0.025),
		"strike_root_position": Vector3(0.06, -0.075, -0.06),
		"recovery_root_position": Vector3(0.012, -0.03, -0.012),
		"windup_root_rotation_degrees": Vector3(2.0, 7.0, -3.0),
		"strike_root_rotation_degrees": Vector3(-4.0, -11.0, 3.5),
		"recovery_root_rotation_degrees": Vector3.ZERO,
		"windup_body_position": Vector3(0.0, -0.035, 0.015),
		"strike_body_position": Vector3(0.0, -0.04, -0.025),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(3.0, 6.0, -2.0),
		"strike_body_rotation_degrees": Vector3(-5.0, -10.0, 2.5),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(18.0, -3.0, -9.0),
		"strike_left_leg_rotation_degrees": Vector3(-15.0, 4.0, 8.0),
		"recovery_left_leg_rotation_degrees": Vector3(3.0, 0.0, -3.0),
		"windup_right_leg_rotation_degrees": Vector3(-14.0, 3.0, 9.0),
		"strike_right_leg_rotation_degrees": Vector3(12.0, -4.0, -8.0),
		"recovery_right_leg_rotation_degrees": Vector3(-3.0, 0.0, 3.0),
		"windup_left_leg_position": Vector3(-0.055, -0.03, -0.035),
		"strike_left_leg_position": Vector3(-0.05, -0.02, 0.04),
		"recovery_left_leg_position": Vector3(-0.015, 0.0, 0.0),
		"windup_right_leg_position": Vector3(0.055, -0.03, 0.035),
		"strike_right_leg_position": Vector3(0.05, -0.02, -0.04),
		"recovery_right_leg_position": Vector3(0.015, 0.0, 0.0),
	},
	"sword_thrust_heavy": {
		"display_name": "Committed Driving Thrust",
		"plant_foot": "right",
		"plant_end": 0.24,
		"drive_end": 0.64,
		"plant_speed": 0.12,
		"peak_speed": 1.82,
		"drive_exit_speed": 0.74,
		"settle_speed": 0.08,
		"steering_multiplier": 0.24,
		"windup_root_position": Vector3(0.0, -0.075, 0.075),
		"strike_root_position": Vector3(0.0, -0.055, -0.15),
		"recovery_root_position": Vector3(0.0, -0.03, -0.035),
		"windup_root_rotation_degrees": Vector3(2.0, 0.0, 0.0),
		"strike_root_rotation_degrees": Vector3(-6.0, 0.0, 0.0),
		"recovery_root_rotation_degrees": Vector3(1.0, 0.0, 0.0),
		"windup_body_position": Vector3(0.0, -0.035, 0.04),
		"strike_body_position": Vector3(0.0, -0.015, -0.07),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(4.0, 0.0, 0.0),
		"strike_body_rotation_degrees": Vector3(-8.0, 0.0, 0.0),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-20.0, 0.0, -4.0),
		"strike_left_leg_rotation_degrees": Vector3(24.0, 0.0, 3.0),
		"recovery_left_leg_rotation_degrees": Vector3(-3.0, 0.0, -1.0),
		"windup_right_leg_rotation_degrees": Vector3(28.0, 0.0, 5.0),
		"strike_right_leg_rotation_degrees": Vector3(-28.0, 0.0, -4.0),
		"recovery_right_leg_rotation_degrees": Vector3(4.0, 0.0, 1.0),
		"windup_left_leg_position": Vector3(-0.015, -0.025, 0.075),
		"strike_left_leg_position": Vector3(-0.015, -0.015, -0.085),
		"recovery_left_leg_position": Vector3.ZERO,
		"windup_right_leg_position": Vector3(0.018, -0.035, -0.09),
		"strike_right_leg_position": Vector3(0.018, -0.015, 0.09),
		"recovery_right_leg_position": Vector3.ZERO,
	},
	"sword_orbit": {
		"display_name": "Orbit Finisher Pivot",
		"plant_foot": "both",
		"plant_end": 0.26,
		"drive_end": 0.77,
		"plant_speed": 0.16,
		"peak_speed": 1.42,
		"drive_exit_speed": 1.02,
		"settle_speed": 0.12,
		"steering_multiplier": 0.18,
		"windup_root_position": Vector3(0.065, -0.095, 0.025),
		"strike_root_position": Vector3(-0.075, -0.085, -0.07),
		"recovery_root_position": Vector3(-0.018, -0.04, -0.018),
		"windup_root_rotation_degrees": Vector3(1.0, -12.0, 4.0),
		"strike_root_rotation_degrees": Vector3(-4.0, 20.0, -4.5),
		"recovery_root_rotation_degrees": Vector3(0.0, 3.0, 0.0),
		"windup_body_position": Vector3(0.0, -0.045, 0.02),
		"strike_body_position": Vector3(0.0, -0.05, -0.035),
		"recovery_body_position": Vector3.ZERO,
		"windup_body_rotation_degrees": Vector3(3.0, -10.0, 3.0),
		"strike_body_rotation_degrees": Vector3(-6.0, 17.0, -3.0),
		"recovery_body_rotation_degrees": Vector3.ZERO,
		"windup_left_leg_rotation_degrees": Vector3(-15.0, -5.0, -11.0),
		"strike_left_leg_rotation_degrees": Vector3(14.0, 6.0, 10.0),
		"recovery_left_leg_rotation_degrees": Vector3(-3.0, 0.0, -4.0),
		"windup_right_leg_rotation_degrees": Vector3(18.0, 5.0, 11.0),
		"strike_right_leg_rotation_degrees": Vector3(-17.0, -6.0, -10.0),
		"recovery_right_leg_rotation_degrees": Vector3(3.0, 0.0, 4.0),
		"windup_left_leg_position": Vector3(-0.065, -0.035, 0.045),
		"strike_left_leg_position": Vector3(-0.06, -0.025, -0.05),
		"recovery_left_leg_position": Vector3(-0.02, 0.0, 0.0),
		"windup_right_leg_position": Vector3(0.065, -0.035, -0.045),
		"strike_right_leg_position": Vector3(0.06, -0.025, 0.05),
		"recovery_right_leg_position": Vector3(0.02, 0.0, 0.0),
	},
}

const ROTATION_PARTS: Array[String] = [
	"root_rotation",
	"body_rotation",
	"left_leg_rotation",
	"right_leg_rotation",
]

const POSITION_PARTS: Array[String] = [
	"root_position",
	"body_position",
	"left_leg_position",
	"right_leg_position",
]

const ALL_POSE_PARTS: Array[String] = [
	"root_rotation",
	"body_rotation",
	"left_leg_rotation",
	"right_leg_rotation",
	"root_position",
	"body_position",
	"left_leg_position",
	"right_leg_position",
]


static func has_profile(profile_id: String) -> bool:
	return profile_id != "" and PROFILES.has(profile_id)


static func resolve_profile_id(attack: WeaponAttackDefinition) -> String:
	if attack == null:
		return ""
	if has_profile(attack.footwork_profile_id):
		return attack.footwork_profile_id
	if has_profile(attack.character_pose_id):
		return attack.character_pose_id
	return ""


static func get_profile(profile_id: String) -> Dictionary:
	if not has_profile(profile_id):
		return {}
	return (PROFILES[profile_id] as Dictionary).duplicate(true)


static func get_display_name(profile_id: String) -> String:
	return str(get_profile(profile_id).get("display_name", profile_id.capitalize()))


static func get_plant_foot(profile_id: String) -> String:
	return str(get_profile(profile_id).get("plant_foot", "both"))


static func get_steering_multiplier(profile_id: String) -> float:
	return clampf(float(get_profile(profile_id).get("steering_multiplier", 1.0)), 0.0, 2.0)


static func sample_speed_multiplier(profile_id: String, progress: float) -> float:
	var profile: Dictionary = get_profile(profile_id)
	if profile.is_empty():
		return 1.0
	var p: float = clampf(progress, 0.0, 1.0)
	var plant_end: float = float(profile.get("plant_end", 0.2))
	var drive_end: float = float(profile.get("drive_end", 0.72))
	var plant_speed: float = float(profile.get("plant_speed", 0.3))
	var peak_speed: float = float(profile.get("peak_speed", 1.45))
	var drive_exit_speed: float = float(profile.get("drive_exit_speed", 0.9))
	var settle_speed: float = float(profile.get("settle_speed", 0.18))
	if p < plant_end:
		var plant_weight: float = smoothstep(0.0, 1.0, p / maxf(plant_end, 0.001))
		return lerpf(plant_speed, peak_speed, plant_weight)
	if p < drive_end:
		var drive_weight: float = smoothstep(
			0.0,
			1.0,
			(p - plant_end) / maxf(drive_end - plant_end, 0.001)
		)
		return lerpf(peak_speed, drive_exit_speed, drive_weight)
	var settle_weight: float = smoothstep(
		0.0,
		1.0,
		(p - drive_end) / maxf(1.0 - drive_end, 0.001)
	)
	return lerpf(drive_exit_speed, settle_speed, settle_weight)


static func get_average_speed_multiplier(profile_id: String, sample_count: int = 64) -> float:
	if not has_profile(profile_id):
		return 1.0
	var count: int = maxi(sample_count, 8)
	var total: float = 0.0
	for index: int in range(count):
		var progress: float = (float(index) + 0.5) / float(count)
		total += sample_speed_multiplier(profile_id, progress)
	return maxf(total / float(count), 0.01)


static func get_motion_phase(profile_id: String, progress: float) -> String:
	var profile: Dictionary = get_profile(profile_id)
	if profile.is_empty():
		return "legacy"
	var p: float = clampf(progress, 0.0, 1.0)
	if p < float(profile.get("plant_end", 0.2)):
		return "plant"
	if p < float(profile.get("drive_end", 0.72)):
		return "drive"
	return "settle"


static func sample_attack_pose(
	profile_id: String,
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float = 1.0
) -> Dictionary:
	var profile: Dictionary = get_profile(profile_id)
	if profile.is_empty() or attack == null:
		return {}
	var phase: Dictionary = _get_attack_phase(attack, elapsed, attack_speed)
	var sample: Dictionary = {
		"profile_id": profile_id,
		"display_name": str(profile.get("display_name", profile_id.capitalize())),
		"plant_foot": str(profile.get("plant_foot", "both")),
		"phase": str(phase.get("phase", "idle")),
		"phase_weight": float(phase.get("weight", 0.0)),
	}
	for part_id: String in ROTATION_PARTS:
		sample[part_id] = _degrees_to_radians(
			_sample_profile_vector(profile, part_id, phase)
		)
	for part_id: String in POSITION_PARTS:
		sample[part_id] = _sample_profile_vector(profile, part_id, phase)
	return sample


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	for profile_id_variant: Variant in PROFILES.keys():
		var profile_id: String = str(profile_id_variant)
		var profile: Dictionary = PROFILES[profile_id_variant] as Dictionary
		if profile_id.strip_edges() == "":
			failures.append("combat footwork profile has an empty id")
		var plant_end: float = float(profile.get("plant_end", -1.0))
		var drive_end: float = float(profile.get("drive_end", -1.0))
		if not (plant_end > 0.0 and plant_end < drive_end and drive_end < 1.0):
			failures.append(profile_id + " has unordered motion phases")
		for speed_field: String in ["plant_speed", "peak_speed", "drive_exit_speed", "settle_speed"]:
			if float(profile.get(speed_field, -1.0)) < 0.0:
				failures.append(profile_id + " has invalid " + speed_field)
		for prefix: String in ["windup_", "strike_", "recovery_"]:
			for part_id: String in ALL_POSE_PARTS:
				var field_name: String = _get_profile_field_name(prefix, part_id)
				var value: Variant = profile.get(field_name, null)
				if not value is Vector3 or not (value as Vector3).is_finite():
					failures.append(profile_id + " has invalid " + field_name)
		if get_average_speed_multiplier(profile_id) <= 0.0:
			failures.append(profile_id + " has no positive root-motion area")
	return failures


static func _get_attack_phase(
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


static func _sample_profile_vector(
	profile: Dictionary,
	part_id: String,
	phase: Dictionary
) -> Vector3:
	var windup: Vector3 = profile.get(
		_get_profile_field_name("windup_", part_id),
		Vector3.ZERO
	)
	var strike: Vector3 = profile.get(
		_get_profile_field_name("strike_", part_id),
		Vector3.ZERO
	)
	var recovery: Vector3 = profile.get(
		_get_profile_field_name("recovery_", part_id),
		Vector3.ZERO
	)
	var weight: float = clampf(float(phase.get("weight", 0.0)), 0.0, 1.0)
	match str(phase.get("phase", "idle")):
		"startup":
			return Vector3.ZERO.lerp(windup, weight)
		"active":
			return windup.lerp(strike, weight)
		"recovery":
			return strike.lerp(recovery, weight)
		_:
			return Vector3.ZERO


static func _get_profile_field_name(prefix: String, part_id: String) -> String:
	var suffix: String = "_degrees" if ROTATION_PARTS.has(part_id) else ""
	return prefix + part_id + suffix


static func _degrees_to_radians(degrees: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(degrees.x),
		deg_to_rad(degrees.y),
		deg_to_rad(degrees.z)
	)
