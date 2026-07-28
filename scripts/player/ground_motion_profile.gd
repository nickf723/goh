extends Resource
class_name GroundMotionProfile

@export_group("Speed")
@export_range(0.5, 20.0, 0.1) var maximum_speed: float = 5.0
@export_range(0.5, 3.0, 0.05) var analog_exponent: float = 1.25
@export_range(0.0, 0.4, 0.01) var input_deadzone: float = 0.08
@export_range(0.0, 3.0, 0.05) var initial_response_speed: float = 0.85
@export_range(0.1, 1.0, 0.01) var lock_on_strafe_multiplier: float = 0.94
@export_range(0.1, 1.0, 0.01) var lock_on_backward_multiplier: float = 0.9

@export_group("Ground Response")
@export_range(1.0, 120.0, 0.5) var acceleration: float = 30.0
@export_range(1.0, 160.0, 0.5) var braking: float = 48.0
@export_range(1.0, 180.0, 0.5) var reversal_acceleration: float = 62.0
@export_range(1.0, 160.0, 0.5) var turn_acceleration: float = 38.0
@export_range(1.0, 180.0, 0.5) var overspeed_braking: float = 58.0
@export_range(-1.0, 1.0, 0.01) var sharp_turn_dot: float = 0.62
@export_range(-1.0, 1.0, 0.01) var reversal_dot: float = -0.58
@export_range(0.01, 1.0, 0.01) var cruise_speed_tolerance: float = 0.12
@export_range(0.001, 0.5, 0.005) var stop_speed: float = 0.06

@export_group("Air Control")
@export_range(0.0, 80.0, 0.5) var air_acceleration: float = 9.0
@export_range(0.0, 30.0, 0.25) var air_drag: float = 1.5

@export_group("Action Handoffs")
@export_range(0.0, 1.0, 0.01) var attack_momentum_retention: float = 0.32
@export_range(0.0, 1.0, 0.01) var dodge_exit_momentum_retention: float = 0.68

@export_group("Presentation")
@export_range(1.0, 40.0, 0.5) var feedback_response: float = 14.0


func validate_profile() -> Array[String]:
	var failures: Array[String] = []
	if maximum_speed <= 0.0:
		failures.append("maximum_speed must be positive")
	if acceleration <= 0.0:
		failures.append("acceleration must be positive")
	if braking <= 0.0:
		failures.append("braking must be positive")
	if reversal_acceleration <= 0.0:
		failures.append("reversal_acceleration must be positive")
	if turn_acceleration <= 0.0:
		failures.append("turn_acceleration must be positive")
	if sharp_turn_dot <= reversal_dot:
		failures.append("sharp_turn_dot must be greater than reversal_dot")
	if input_deadzone < 0.0 or input_deadzone >= 1.0:
		failures.append("input_deadzone must be in [0, 1)")
	if analog_exponent <= 0.0:
		failures.append("analog_exponent must be positive")
	if stop_speed <= 0.0:
		failures.append("stop_speed must be positive")
	return failures
