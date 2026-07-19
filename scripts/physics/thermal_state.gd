extends Node
class_name ThermalState

signal temperature_changed(temperature_c: float, delta_c: float, source_name: String)
signal phase_changed(previous_phase: String, next_phase: String)
signal ignition_state_changed(is_ignited: bool)

@export var material_profile: PhysicalMaterialProfile
@export var mass_kg: float = 1.0
@export var heat_capacity_override_j_per_c: float = 0.0
@export_range(0.0001, 1.0, 0.0001) var gameplay_heat_capacity_scale: float = 0.01

@export_group("Temperature")
@export var starting_temperature_c: float = 20.0
@export var ambient_temperature_c: float = 20.0
@export var minimum_temperature_c: float = -273.15
@export var maximum_temperature_c: float = 2000.0
@export var passive_ambient_exchange: bool = true
@export var ambient_conductance_j_per_second_c: float = 0.08

@export_group("Payload Energy")
@export var fire_energy_j_per_intensity: float = 180.0
@export var ice_energy_j_per_intensity: float = 180.0

@export_group("Phase")
@export var phase_changes_enabled: bool = false
@export var use_material_phase_points: bool = true
@export var freezing_point_c: float = 0.0
@export var boiling_point_c: float = 100.0
@export var phase_hysteresis_c: float = 1.0

@export_group("Ignition")
@export var ignition_enabled: bool = false
@export var use_material_ignition_point: bool = true
@export var ignition_temperature_c: float = 300.0
@export var ignition_hysteresis_c: float = 12.0

var temperature_c: float = 20.0
var phase: String = "stable"
var ignited: bool = false
var last_energy_j: float = 0.0
var last_source_name: String = "initial"


func _ready() -> void:
	temperature_c = clampf(starting_temperature_c, minimum_temperature_c, maximum_temperature_c)
	phase = get_initial_phase()
	ignited = should_be_ignited(false)
	add_to_group("thermal_states")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _process(delta: float) -> void:
	if not passive_ambient_exchange:
		return
	var difference_c: float = ambient_temperature_c - temperature_c
	if absf(difference_c) <= 0.001:
		return
	var energy_j: float = difference_c * max(ambient_conductance_j_per_second_c, 0.0) * delta
	if absf(energy_j) > 0.0001:
		apply_energy_j(energy_j, "Ambient")


func get_heat_capacity_j_per_c() -> float:
	if heat_capacity_override_j_per_c > 0.0:
		return heat_capacity_override_j_per_c
	if material_profile != null:
		return max(
			material_profile.specific_heat_capacity_j_kg_c
			* max(mass_kg, 0.001)
			* max(gameplay_heat_capacity_scale, 0.0001),
			0.01
		)
	return max(1000.0 * max(mass_kg, 0.001) * max(gameplay_heat_capacity_scale, 0.0001), 0.01)


func get_thermal_conductivity() -> float:
	if material_profile != null:
		return max(material_profile.thermal_conductivity_w_m_c, 0.0)
	return 0.5


func get_freezing_point_c() -> float:
	if use_material_phase_points and material_profile != null:
		return material_profile.freezing_point_c
	return freezing_point_c


func get_boiling_point_c() -> float:
	if use_material_phase_points and material_profile != null:
		return material_profile.boiling_point_c
	return boiling_point_c


func get_ignition_temperature_c() -> float:
	if use_material_ignition_point and material_profile != null:
		return material_profile.ignition_temperature_c
	return ignition_temperature_c


func apply_energy_j(energy_j: float, source_name: String = "Unknown") -> float:
	if is_zero_approx(energy_j):
		return 0.0
	var delta_c: float = energy_j / get_heat_capacity_j_per_c()
	last_energy_j = energy_j
	last_source_name = source_name
	return set_temperature(temperature_c + delta_c, source_name)


func apply_temperature_delta(delta_c: float, source_name: String = "Unknown") -> float:
	return set_temperature(temperature_c + delta_c, source_name)


func set_temperature(next_temperature_c: float, source_name: String = "Unknown") -> float:
	var previous_temperature_c: float = temperature_c
	temperature_c = clampf(next_temperature_c, minimum_temperature_c, maximum_temperature_c)
	var actual_delta_c: float = temperature_c - previous_temperature_c
	if absf(actual_delta_c) <= 0.0001:
		return 0.0
	last_source_name = source_name
	update_phase_from_temperature()
	update_ignition_state()
	temperature_changed.emit(temperature_c, actual_delta_c, source_name)
	return actual_delta_c


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var thermal_kind: String = get_payload_thermal_kind(payload)
	if thermal_kind == "":
		return {}
	var intensity: float = max(absf(float(payload.amount)), absf(payload.status_strength), 1.0)
	var energy_j: float = fire_energy_j_per_intensity * intensity
	if thermal_kind == "cold":
		energy_j = -ice_energy_j_per_intensity * intensity
	var delta_c: float = apply_energy_j(energy_j, payload.source_name)
	return {
		"message": (
			payload.source_name
			+ (" heats " if delta_c >= 0.0 else " cools ")
			+ get_parent().name
			+ " to "
			+ str(snapped(temperature_c, 0.1))
			+ " °C."
		),
		"objective": "Observe temperature, phase, and conductivity respond to shared energy inputs.",
		"temperature_c": temperature_c,
		"delta_c": delta_c,
		"phase": phase,
	}


func get_payload_thermal_kind(payload: DamagePayload) -> String:
	var normalized_element: String = payload.element.to_lower().strip_edges()
	if normalized_element == "fire":
		return "heat"
	if normalized_element == "ice":
		return "cold"
	for raw_tag: String in payload.tags:
		var tag: String = raw_tag.to_lower().strip_edges()
		if tag in ["fire", "heat", "hot", "burn", "burning", "ignite"]:
			return "heat"
		if tag in ["ice", "cold", "chill", "chilled", "freeze", "frozen"]:
			return "cold"
	return ""


func get_initial_phase() -> String:
	if not phase_changes_enabled:
		return "stable"
	if temperature_c <= get_freezing_point_c():
		return "solid"
	if temperature_c >= get_boiling_point_c():
		return "gas"
	return "liquid"


func update_phase_from_temperature() -> void:
	var previous_phase: String = phase
	if not phase_changes_enabled:
		phase = "stable"
	else:
		var freeze_c: float = get_freezing_point_c()
		var boil_c: float = max(get_boiling_point_c(), freeze_c + 0.01)
		var hysteresis_c: float = max(phase_hysteresis_c, 0.0)
		match phase:
			"solid":
				if temperature_c >= boil_c:
					phase = "gas"
				elif temperature_c >= freeze_c + hysteresis_c:
					phase = "liquid"
			"gas":
				if temperature_c <= freeze_c:
					phase = "solid"
				elif temperature_c <= boil_c - hysteresis_c:
					phase = "liquid"
			_:
				if temperature_c <= freeze_c:
					phase = "solid"
				elif temperature_c >= boil_c:
					phase = "gas"
				else:
					phase = "liquid"
	if phase != previous_phase:
		phase_changed.emit(previous_phase, phase)


func should_be_ignited(previous_state: bool) -> bool:
	if not ignition_enabled:
		return false
	var threshold_c: float = get_ignition_temperature_c()
	if previous_state:
		return temperature_c >= threshold_c - max(ignition_hysteresis_c, 0.0)
	return temperature_c >= threshold_c


func update_ignition_state() -> void:
	var next_ignited: bool = should_be_ignited(ignited)
	if next_ignited == ignited:
		return
	ignited = next_ignited
	ignition_state_changed.emit(ignited)


func is_solid() -> bool:
	return phase == "solid"


func is_liquid() -> bool:
	return phase == "liquid"


func is_gas() -> bool:
	return phase == "gas"


func reset_target() -> void:
	last_energy_j = 0.0
	last_source_name = "reset"
	set_temperature(starting_temperature_c, "Reset")
	phase = get_initial_phase()
	update_ignition_state()


func get_debug_data() -> Dictionary:
	return {
		"thermal_state": true,
		"temperature_c": snapped(temperature_c, 0.01),
		"ambient_temperature_c": snapped(ambient_temperature_c, 0.01),
		"heat_capacity_j_per_c": snapped(get_heat_capacity_j_per_c(), 0.01),
		"thermal_conductivity": snapped(get_thermal_conductivity(), 0.01),
		"phase": phase,
		"ignited": ignited,
		"last_energy_j": snapped(last_energy_j, 0.01),
		"last_source": last_source_name,
		"material": material_profile.material_id if material_profile != null else "generic",
	}
