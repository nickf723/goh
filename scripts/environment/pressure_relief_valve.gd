extends Area3D
class_name PressureReliefValve

signal vented(amount: float, automatic: bool)

@export var prompt_text: String = "Vent boiler pressure"
@export_range(0.1, 1.0, 0.01) var automatic_threshold_ratio: float = 0.9
@export var automatic_vent_per_second: float = 36.0
@export var manual_vent_amount: float = 1000.0

var reservoir: PressureReservoir
var total_vented: float = 0.0
var automatic_venting: bool = false


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _process(delta: float) -> void:
	if reservoir == null or delta <= 0.0:
		automatic_venting = false
		return
	var threshold: float = reservoir.maximum_pressure * automatic_threshold_ratio
	automatic_venting = reservoir.current_pressure >= threshold
	if automatic_venting:
		vent_pressure(automatic_vent_per_second * delta, true)


func configure(next_reservoir: PressureReservoir) -> void:
	reservoir = next_reservoir


func interact() -> Dictionary:
	var removed: float = vent_pressure(manual_vent_amount, false)
	return {
		"message": "Relief valve vents " + str(snapped(removed, 0.1)) + " pressure units.",
		"objective": "Heat the boiler to rebuild pressure, or cool it to condense the steam.",
	}


func vent_pressure(amount: float, automatic: bool) -> float:
	if reservoir == null or amount <= 0.0:
		return 0.0
	var removed: float = reservoir.remove_pressure(
		amount,
		"automatic relief" if automatic else "manual relief"
	)
	if removed > 0.0:
		total_vented += removed
		vented.emit(removed, automatic)
	return removed


func reset_target() -> void:
	total_vented = 0.0
	automatic_venting = false


func get_debug_data() -> Dictionary:
	return {
		"pressure_relief_valve": true,
		"automatic_threshold_ratio": automatic_threshold_ratio,
		"automatic_venting": automatic_venting,
		"total_vented": snapped(total_vented, 0.1),
		"pressure": snapped(reservoir.current_pressure, 0.1) if reservoir != null else 0.0,
	}
