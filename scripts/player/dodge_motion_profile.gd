extends Resource
class_name DodgeMotionProfile

@export_group("Motion")
@export_range(0.2, 4.0, 0.01) var distance: float = 1.72
@export_range(0.12, 0.8, 0.01) var duration: float = 0.28
@export_range(0.0, 1.0, 0.01) var cooldown: float = 0.14
@export_range(0, 8, 1) var stamina_cost: int = 1

@export_group("Speed Curve")
@export_range(0.02, 0.4, 0.01) var launch_end: float = 0.16
@export_range(0.2, 0.85, 0.01) var travel_end: float = 0.62
@export_range(0.55, 0.98, 0.01) var landing_end: float = 0.86
@export_range(0.05, 2.0, 0.01) var launch_speed_multiplier: float = 0.78
@export_range(0.2, 2.5, 0.01) var peak_speed_multiplier: float = 1.35
@export_range(0.1, 2.0, 0.01) var travel_exit_multiplier: float = 1.02
@export_range(0.0, 1.5, 0.01) var recovery_exit_multiplier: float = 0.24

@export_group("Direction Variants")
@export_range(0.2, 1.5, 0.01) var forward_distance_multiplier: float = 1.0
@export_range(0.2, 1.5, 0.01) var side_distance_multiplier: float = 0.94
@export_range(0.2, 1.5, 0.01) var backward_distance_multiplier: float = 0.88
@export_range(0.2, 1.5, 0.01) var backstep_distance_multiplier: float = 0.82

@export_group("Late Steering")
@export_range(0.0, 1.0, 0.01) var steering_start: float = 0.56
@export_range(0.0, 1.0, 0.01) var steering_end: float = 0.88
@export_range(0.0, 1.0, 0.01) var steering_strength: float = 0.42
@export_range(0.0, 720.0, 5.0) var steering_turn_speed_degrees: float = 260.0

@export_group("Invulnerability")
@export_range(0.0, 1.0, 0.01) var invulnerability_start: float = 0.1
@export_range(0.0, 1.0, 0.01) var invulnerability_end: float = 0.7

@export_group("Follow-up Windows")
@export_range(0.0, 1.0, 0.01) var attack_cancel_start: float = 0.0
@export_range(0.0, 1.0, 0.01) var cast_cancel_start: float = 0.72
@export_range(0.0, 1.0, 0.01) var guard_cancel_start: float = 0.76
@export_range(0.0, 1.0, 0.01) var chain_start: float = 0.76
@export_range(0.0, 1.0, 0.01) var chain_end: float = 0.96
@export_range(1, 6, 1) var maximum_consecutive_dodges: int = 2
@export_range(0.02, 0.5, 0.01) var input_buffer_seconds: float = 0.18

@export_group("Presentation")
@export_range(1.0, 4.0, 0.05) var iframe_emission_multiplier: float = 2.15
@export_range(0.0, 0.2, 0.005) var launch_compression: float = 0.055
@export_range(0.0, 0.2, 0.005) var landing_compression: float = 0.085
@export_range(0.0, 0.4, 0.01) var body_lean_radians: float = 0.18


func sample_speed_multiplier(progress: float) -> float:
	var p: float = clampf(progress, 0.0, 1.0)
	if p < launch_end:
		var launch_weight: float = smoothstep(0.0, 1.0, p / maxf(launch_end, 0.001))
		return lerpf(launch_speed_multiplier, peak_speed_multiplier, launch_weight)
	if p < travel_end:
		var travel_weight: float = smoothstep(
			0.0,
			1.0,
			(p - launch_end) / maxf(travel_end - launch_end, 0.001)
		)
		return lerpf(peak_speed_multiplier, travel_exit_multiplier, travel_weight)
	var recovery_weight: float = smoothstep(
		0.0,
		1.0,
		(p - travel_end) / maxf(1.0 - travel_end, 0.001)
	)
	return lerpf(travel_exit_multiplier, recovery_exit_multiplier, recovery_weight)


func get_average_speed_multiplier(sample_count: int = 48) -> float:
	var count: int = maxi(sample_count, 4)
	var total: float = 0.0
	for index: int in range(count):
		var progress: float = (float(index) + 0.5) / float(count)
		total += sample_speed_multiplier(progress)
	return maxf(total / float(count), 0.01)


func get_distance_multiplier(direction_kind: String) -> float:
	match direction_kind:
		"side":
			return side_distance_multiplier
		"backward":
			return backward_distance_multiplier
		"backstep":
			return backstep_distance_multiplier
		_:
			return forward_distance_multiplier


func get_phase(progress: float) -> String:
	var p: float = clampf(progress, 0.0, 1.0)
	if p < launch_end:
		return "launch"
	if p < travel_end:
		return "travel"
	if p < landing_end:
		return "landing"
	return "recovery"


func validate_profile() -> Array[String]:
	var failures: Array[String] = []
	if distance <= 0.0:
		failures.append("distance must be positive")
	if duration <= 0.0:
		failures.append("duration must be positive")
	if not (launch_end > 0.0 and launch_end < travel_end):
		failures.append("launch_end must be between zero and travel_end")
	if not (travel_end < landing_end and landing_end < 1.0):
		failures.append("travel_end and landing_end must be ordered below one")
	if not (steering_start <= steering_end):
		failures.append("steering_start must not exceed steering_end")
	if not (invulnerability_start < invulnerability_end):
		failures.append("invulnerability_start must be before invulnerability_end")
	if not (chain_start < chain_end):
		failures.append("chain_start must be before chain_end")
	if maximum_consecutive_dodges < 1:
		failures.append("maximum_consecutive_dodges must be at least one")
	if get_average_speed_multiplier() <= 0.0:
		failures.append("speed curve must have positive area")
	return failures
