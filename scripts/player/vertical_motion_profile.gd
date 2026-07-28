extends Resource
class_name VerticalMotionProfile

@export_group("Input Forgiveness")
@export_range(0.0, 0.4, 0.01) var coyote_seconds: float = 0.12
@export_range(0.0, 0.4, 0.01) var jump_buffer_seconds: float = 0.12

@export_group("Jump Shape")
@export_range(0.5, 1.5, 0.01) var launch_velocity_multiplier: float = 1.0
@export_range(0.05, 1.0, 0.01) var jump_release_velocity_multiplier: float = 0.52
@export_range(0.0, 0.2, 0.005) var minimum_hold_seconds: float = 0.035
@export_range(0.0, 4.0, 0.05) var minimum_release_velocity: float = 0.45
@export_range(0.01, 0.3, 0.01) var launch_phase_seconds: float = 0.08

@export_group("Gravity Shape")
@export_range(0.1, 3.0, 0.01) var rising_gravity_scale: float = 1.0
@export_range(0.1, 3.0, 0.01) var apex_gravity_scale: float = 0.72
@export_range(0.1, 4.0, 0.01) var falling_gravity_scale: float = 1.18
@export_range(0.1, 5.0, 0.01) var jump_cut_gravity_scale: float = 1.55
@export_range(0.05, 4.0, 0.05) var apex_velocity_threshold: float = 0.65
@export_range(2.0, 80.0, 0.5) var terminal_fall_speed: float = 22.0

@export_group("Landing Classification")
@export_range(0.0, 12.0, 0.1) var minimum_landing_speed: float = 2.8
@export_range(0.1, 18.0, 0.1) var soft_landing_speed: float = 4.6
@export_range(0.2, 30.0, 0.1) var hard_landing_speed: float = 8.8
@export_range(0.01, 0.6, 0.01) var minimum_landing_pose_seconds: float = 0.1
@export_range(0.01, 0.8, 0.01) var maximum_landing_pose_seconds: float = 0.28

@export_group("Wire Presentation")
@export_range(0.0, 0.2, 0.005) var launch_compression: float = 0.065
@export_range(0.0, 0.2, 0.005) var rising_extension: float = 0.035
@export_range(0.0, 0.2, 0.005) var apex_float: float = 0.025
@export_range(0.0, 0.4, 0.01) var falling_brace_radians: float = 0.14
@export_range(0.0, 0.3, 0.005) var landing_compression: float = 0.12
@export_range(1.0, 40.0, 0.5) var pose_response: float = 20.0


func get_gravity_scale(vertical_velocity: float, jump_cut_active: bool = false) -> float:
	var scale: float = falling_gravity_scale
	if vertical_velocity > apex_velocity_threshold:
		scale = rising_gravity_scale
	elif vertical_velocity >= -apex_velocity_threshold:
		scale = apex_gravity_scale
	if jump_cut_active and vertical_velocity > 0.0:
		scale = maxf(scale, jump_cut_gravity_scale)
	return maxf(scale, 0.0)


func classify_landing(impact_speed: float) -> String:
	var speed: float = maxf(impact_speed, 0.0)
	if speed < minimum_landing_speed:
		return "settled"
	if speed < soft_landing_speed:
		return "light"
	if speed < hard_landing_speed:
		return "firm"
	return "hard"


func get_landing_strength(impact_speed: float) -> float:
	if impact_speed < minimum_landing_speed:
		return 0.0
	return clampf(
		inverse_lerp(minimum_landing_speed, hard_landing_speed * 1.18, impact_speed),
		0.0,
		1.0
	)


func get_landing_pose_duration(impact_speed: float) -> float:
	return lerpf(
		minimum_landing_pose_seconds,
		maximum_landing_pose_seconds,
		get_landing_strength(impact_speed)
	)


func validate_profile() -> Array[String]:
	var failures: Array[String] = []
	if coyote_seconds < 0.0:
		failures.append("coyote_seconds must not be negative")
	if jump_buffer_seconds < 0.0:
		failures.append("jump_buffer_seconds must not be negative")
	if launch_velocity_multiplier <= 0.0:
		failures.append("launch_velocity_multiplier must be positive")
	if jump_release_velocity_multiplier <= 0.0 or jump_release_velocity_multiplier > 1.0:
		failures.append("jump_release_velocity_multiplier must be in (0, 1]")
	if rising_gravity_scale <= 0.0:
		failures.append("rising_gravity_scale must be positive")
	if apex_gravity_scale <= 0.0:
		failures.append("apex_gravity_scale must be positive")
	if falling_gravity_scale <= 0.0:
		failures.append("falling_gravity_scale must be positive")
	if jump_cut_gravity_scale < rising_gravity_scale:
		failures.append("jump_cut_gravity_scale must not be lower than rising_gravity_scale")
	if apex_velocity_threshold <= 0.0:
		failures.append("apex_velocity_threshold must be positive")
	if terminal_fall_speed <= 0.0:
		failures.append("terminal_fall_speed must be positive")
	if minimum_landing_speed < 0.0:
		failures.append("minimum_landing_speed must not be negative")
	if soft_landing_speed <= minimum_landing_speed:
		failures.append("soft_landing_speed must exceed minimum_landing_speed")
	if hard_landing_speed <= soft_landing_speed:
		failures.append("hard_landing_speed must exceed soft_landing_speed")
	if maximum_landing_pose_seconds < minimum_landing_pose_seconds:
		failures.append("maximum_landing_pose_seconds must not be shorter than minimum")
	if pose_response <= 0.0:
		failures.append("pose_response must be positive")
	return failures
