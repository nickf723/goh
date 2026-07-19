extends Node
class_name PressureTurbine

signal running_state_changed(is_running: bool)

@export var enabled: bool = true
@export var minimum_operating_pressure: float = 8.0
@export var full_speed_pressure: float = 70.0
@export var maximum_rpm: float = 1500.0
@export var idle_consumption_per_second: float = 2.0
@export var full_consumption_per_second: float = 16.0
@export var response_exponent: float = 0.85

var reservoir: PressureReservoir
var shaft: RotationalShaftState
var running: bool = false
var last_pressure_ratio: float = 0.0
var last_target_rpm: float = 0.0
var last_consumption_rate: float = 0.0
var total_pressure_consumed: float = 0.0


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _process(delta: float) -> void:
	step_turbine(delta)


func configure(next_reservoir: PressureReservoir, next_shaft: RotationalShaftState) -> void:
	reservoir = next_reservoir
	shaft = next_shaft


func step_turbine(delta: float) -> float:
	if delta <= 0.0 or not enabled or reservoir == null or shaft == null:
		set_running(false)
		last_pressure_ratio = 0.0
		last_target_rpm = 0.0
		last_consumption_rate = 0.0
		if shaft != null:
			shaft.stop_drive("pressure turbine inactive")
		return 0.0

	var pressure: float = reservoir.current_pressure
	if pressure <= minimum_operating_pressure:
		set_running(false)
		last_pressure_ratio = 0.0
		last_target_rpm = 0.0
		last_consumption_rate = 0.0
		shaft.stop_drive("insufficient pressure")
		return 0.0

	var pressure_span: float = max(full_speed_pressure - minimum_operating_pressure, 0.01)
	last_pressure_ratio = clampf((pressure - minimum_operating_pressure) / pressure_span, 0.0, 1.0)
	var shaped_ratio: float = pow(last_pressure_ratio, max(response_exponent, 0.01))
	last_target_rpm = max(maximum_rpm, 0.0) * shaped_ratio
	last_consumption_rate = lerpf(
		max(idle_consumption_per_second, 0.0),
		max(full_consumption_per_second, 0.0),
		last_pressure_ratio
	)
	var consumed: float = reservoir.remove_pressure(
		last_consumption_rate * delta,
		"pressure turbine"
	)
	total_pressure_consumed += consumed
	shaft.set_target_rpm(last_target_rpm, "pressure turbine")
	set_running(consumed > 0.0 and last_target_rpm > 0.0)
	return consumed


func set_running(next_running: bool) -> void:
	if running == next_running:
		return
	running = next_running
	running_state_changed.emit(running)


func reset_target() -> void:
	running = false
	last_pressure_ratio = 0.0
	last_target_rpm = 0.0
	last_consumption_rate = 0.0
	total_pressure_consumed = 0.0
	if shaft != null:
		shaft.stop_drive("turbine reset")


func get_debug_data() -> Dictionary:
	return {
		"pressure_turbine": true,
		"running": running,
		"pressure": snapped(reservoir.current_pressure, 0.1) if reservoir != null else 0.0,
		"pressure_ratio": snapped(last_pressure_ratio, 0.01),
		"target_rpm": snapped(last_target_rpm, 0.1),
		"consumption_rate": snapped(last_consumption_rate, 0.01),
		"total_consumed": snapped(total_pressure_consumed, 0.1),
	}
