extends Resource
class_name CombatFootworkProfile

@export_group("Direction Control")
@export_range(0.0, 1.0, 0.01) var steering_start: float = 0.5
@export_range(0.0, 1.0, 0.01) var steering_end: float = 0.88
@export_range(0.0, 1.0, 0.01) var steering_strength: float = 0.2
@export_range(0.0, 720.0, 5.0) var steering_turn_speed_degrees: float = 180.0
@export_range(0.0, 90.0, 1.0) var maximum_steering_degrees: float = 18.0

@export_group("Collision Response")
@export_range(0.0, 1.0, 0.01) var blocked_distance_ratio: float = 0.24
@export_range(1, 8, 1) var blocked_frames_to_stop: int = 2
@export_range(0.0001, 0.1, 0.001) var minimum_expected_displacement: float = 0.004
@export var stop_root_motion_when_blocked: bool = true

@export_group("Timing Safety")
@export_range(0.01, 0.2, 0.005) var minimum_motion_duration: float = 0.05
@export_range(0.1, 1.0, 0.01) var maximum_motion_duration: float = 0.45

@export_group("Presentation")
@export_range(0.0, 2.0, 0.05) var pose_strength: float = 1.0
@export_range(1.0, 40.0, 0.5) var pose_response: float = 22.0
@export_range(0.0, 1.0, 0.01) var direction_alignment_strength: float = 0.9
@export_range(0.0, 120.0, 1.0) var maximum_visual_alignment_degrees: float = 72.0


func validate_profile() -> Array[String]:
	var failures: Array[String] = []
	if steering_start < 0.0 or steering_start > 1.0:
		failures.append("steering_start must be in [0, 1]")
	if steering_end < steering_start or steering_end > 1.0:
		failures.append("steering_end must be ordered after steering_start")
	if maximum_steering_degrees < 0.0:
		failures.append("maximum_steering_degrees must not be negative")
	if blocked_distance_ratio < 0.0 or blocked_distance_ratio > 1.0:
		failures.append("blocked_distance_ratio must be in [0, 1]")
	if blocked_frames_to_stop < 1:
		failures.append("blocked_frames_to_stop must be at least one")
	if minimum_expected_displacement <= 0.0:
		failures.append("minimum_expected_displacement must be positive")
	if minimum_motion_duration <= 0.0:
		failures.append("minimum_motion_duration must be positive")
	if maximum_motion_duration < minimum_motion_duration:
		failures.append("maximum_motion_duration must not be shorter than minimum_motion_duration")
	if pose_strength < 0.0:
		failures.append("pose_strength must not be negative")
	if direction_alignment_strength < 0.0 or direction_alignment_strength > 1.0:
		failures.append("direction_alignment_strength must be in [0, 1]")
	if maximum_visual_alignment_degrees < 0.0:
		failures.append("maximum_visual_alignment_degrees must not be negative")
	return failures
