extends Node
class_name PressureReservoir

signal pressure_changed(current_pressure: float, maximum_pressure: float, delta_pressure: float, source: String)
signal pressure_filled(current_pressure: float)
signal pressure_emptied

@export var maximum_pressure: float = 100.0
@export var starting_pressure: float = 0.0
@export var leak_per_second: float = 1.5
@export var leak_enabled: bool = true

var current_pressure: float = 0.0
var last_source: String = "none"
var last_delta: float = 0.0
var total_received: float = 0.0
var total_released: float = 0.0


func _ready() -> void:
	current_pressure = clampf(starting_pressure, 0.0, max(maximum_pressure, 0.0))
	add_to_group("debuggable")


func _process(delta: float) -> void:
	if not leak_enabled or leak_per_second <= 0.0 or current_pressure <= 0.0:
		return
	remove_pressure(leak_per_second * delta, "pressure leak")


func receive_element_output(
	_element: String,
	amount: float,
	source: String = "unknown",
	_tags: Array[String] = []
) -> float:
	return add_pressure(amount, source)


func add_pressure(amount: float, source: String = "unknown") -> float:
	if amount <= 0.0 or maximum_pressure <= 0.0:
		return 0.0

	var previous: float = current_pressure
	current_pressure = min(current_pressure + amount, maximum_pressure)
	var accepted: float = current_pressure - previous

	if accepted <= 0.0:
		return 0.0

	last_source = source
	last_delta = accepted
	total_received += accepted
	pressure_changed.emit(current_pressure, maximum_pressure, accepted, source)

	if is_full():
		pressure_filled.emit(current_pressure)

	return accepted


func remove_pressure(amount: float, source: String = "release") -> float:
	if amount <= 0.0 or current_pressure <= 0.0:
		return 0.0

	var previous: float = current_pressure
	current_pressure = max(current_pressure - amount, 0.0)
	var removed: float = previous - current_pressure

	last_source = source
	last_delta = -removed
	total_released += removed
	pressure_changed.emit(current_pressure, maximum_pressure, -removed, source)

	if is_zero_approx(current_pressure):
		pressure_emptied.emit()

	return removed


func set_pressure(value: float, source: String = "set") -> void:
	var next_pressure: float = clampf(value, 0.0, max(maximum_pressure, 0.0))
	var delta_pressure: float = next_pressure - current_pressure
	if is_zero_approx(delta_pressure):
		return

	current_pressure = next_pressure
	last_source = source
	last_delta = delta_pressure
	pressure_changed.emit(current_pressure, maximum_pressure, delta_pressure, source)


func get_pressure_ratio() -> float:
	if maximum_pressure <= 0.0:
		return 0.0
	return clampf(current_pressure / maximum_pressure, 0.0, 1.0)


func is_full() -> bool:
	return maximum_pressure > 0.0 and current_pressure >= maximum_pressure


func reset_pressure() -> void:
	current_pressure = clampf(starting_pressure, 0.0, max(maximum_pressure, 0.0))
	last_source = "reset"
	last_delta = 0.0
	total_received = 0.0
	total_released = 0.0
	pressure_changed.emit(current_pressure, maximum_pressure, 0.0, "reset")


func get_debug_data() -> Dictionary:
	return {
		"pressure": snapped(current_pressure, 0.1),
		"maximum": snapped(maximum_pressure, 0.1),
		"ratio": snapped(get_pressure_ratio(), 0.01),
		"leak_per_second": leak_per_second if leak_enabled else 0.0,
		"last_source": last_source,
		"last_delta": snapped(last_delta, 0.1),
		"received": snapped(total_received, 0.1),
		"released": snapped(total_released, 0.1),
	}
