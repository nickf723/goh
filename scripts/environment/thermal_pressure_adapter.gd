extends Node
class_name ThermalPressureAdapter

var thermal_state: ThermalState
var reservoir: PressureReservoir

func configure(next_thermal_state: ThermalState, next_reservoir: PressureReservoir) -> void:
	thermal_state = next_thermal_state
	reservoir = next_reservoir
