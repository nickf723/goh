extends Node
class_name ThermalPressureAdapter

signal generation_state_changed(is_generating: bool)

@export var enabled: bool = true
@export var base_output_per_second: float = 18.0
@export var output_per_superheat_c: float = 0.55
@export var maximum_output_per_second: float = 42.0
@export var condensation_per_second: float = 28.0

var thermal_state: ThermalState
var reservoir: PressureReservoir
var generating: bool = false
var last_output_rate: float = 0.0
var total_generated: float = 0.0
var total_condensed: float = 0.0


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _process(delta: float) -> void:
	step_conversion(delta)


func configure(next_thermal_state: ThermalState, next_reservoir: PressureReservoir) -> void:
	thermal_state = next_thermal_state
	reservoir = next_reservoir


func step_conversion(delta: float) -> float:
	if not enabled or delta <= 0.0 or thermal_state == null or reservoir == null:
		set_generating(false)
		last_output_rate = 0.0
		return 0.0
	if thermal_state.is_gas():
		var rate: float = get_generation_rate()
		var accepted: float = reservoir.add_pressure(rate * delta, "thermal steam")
		last_output_rate = rate
		total_generated += accepted
		set_generating(true)
		return accepted
	var removed: float = reservoir.remove_pressure(
		max(condensation_per_second, 0.0) * delta,
		"steam condensation"
	)
	last_output_rate = -condensation_per_second if removed > 0.0 else 0.0
	total_condensed += removed
	set_generating(false)
	return -removed


func get_generation_rate() -> float:
	if thermal_state == null or not thermal_state.is_gas():
		return 0.0
	var superheat_c: float = max(
		thermal_state.temperature_c - thermal_state.get_boiling_point_c(),
		0.0
	)
	return min(
		max(base_output_per_second, 0.0)
		+ superheat_c * max(output_per_superheat_c, 0.0),
		max(maximum_output_per_second, 0.0)
	)


func set_generating(next_value: bool) -> void:
	if generating == next_value:
		return
	generating = next_value
	generation_state_changed.emit(generating)


func reset_target() -> void:
	generating = false
	last_output_rate = 0.0
	total_generated = 0.0
	total_condensed = 0.0


func get_debug_data() -> Dictionary:
	return {
		"thermal_pressure_adapter": true,
		"generating": generating,
		"output_rate": snapped(last_output_rate, 0.01),
		"temperature_c": snapped(thermal_state.temperature_c, 0.1) if thermal_state != null else 0.0,
		"phase": thermal_state.phase if thermal_state != null else "missing",
		"stored_pressure": snapped(reservoir.current_pressure, 0.1) if reservoir != null else 0.0,
		"generated": snapped(total_generated, 0.1),
		"condensed": snapped(total_condensed, 0.1),
	}
