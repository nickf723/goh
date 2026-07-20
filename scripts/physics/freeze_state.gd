extends Node
class_name FreezeState

signal freeze_progress_changed(progress: float, delta_progress: float)
signal fracture_changed(stress: float, delta_stress: float)
signal cracked(source_name: String)
signal shattered(source_name: String)
signal thawed(source_name: String)

@export var thermal_state_path: NodePath
@export var auto_process: bool = true
@export var starts_frozen: bool = false

@export_group("Phase Response")
@export var freezing_point_c: float = 0.0
@export var thaw_hysteresis_c: float = 1.5
@export var freeze_rate_per_second: float = 0.22
@export var thaw_rate_per_second: float = 0.18
@export var cold_rate_scale: float = 0.035
@export var warm_rate_scale: float = 0.025

@export_group("Fracture")
@export var crack_threshold: float = 0.42
@export var shatter_threshold: float = 1.0
@export var minimum_fracture_progress: float = 0.18
@export var cold_brittleness_scale: float = 0.018
@export var passive_stress_recovery_per_second: float = 0.04

var thermal_state: ThermalState
var freeze_progress: float = 0.0
var fracture_stress: float = 0.0
var is_cracked: bool = false
var is_shattered: bool = false
var last_source_name: String = "initial"
var maximum_freeze_progress: float = 0.0
var total_impact_strength: float = 0.0


func _ready() -> void:
	resolve_dependencies()
	freeze_progress = 1.0 if starts_frozen else get_initial_progress()
	maximum_freeze_progress = freeze_progress
	add_to_group("freeze_states")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	freeze_progress_changed.emit(freeze_progress, 0.0)


func _process(delta: float) -> void:
	if auto_process:
		step_freezing(delta)


func configure(next_thermal_state: ThermalState, next_starts_frozen: bool = false) -> void:
	thermal_state = next_thermal_state
	starts_frozen = next_starts_frozen
	freeze_progress = 1.0 if starts_frozen else get_initial_progress()
	maximum_freeze_progress = freeze_progress


func resolve_dependencies() -> void:
	if thermal_state != null:
		return
	if not thermal_state_path.is_empty():
		thermal_state = get_node_or_null(thermal_state_path) as ThermalState
	if thermal_state == null and get_parent() != null:
		thermal_state = get_parent().get_node_or_null("ThermalState") as ThermalState


func step_freezing(delta: float) -> void:
	var safe_delta: float = max(delta, 0.0)
	resolve_dependencies()
	if is_shattered:
		return
	var temperature_c: float = get_temperature_c()
	var previous_progress: float = freeze_progress
	if temperature_c <= freezing_point_c:
		var coldness: float = freezing_point_c - temperature_c
		var rate: float = freeze_rate_per_second * (1.0 + coldness * cold_rate_scale)
		freeze_progress = clampf(freeze_progress + rate * safe_delta, 0.0, 1.0)
	elif temperature_c >= freezing_point_c + thaw_hysteresis_c:
		var warmth: float = temperature_c - freezing_point_c
		var rate: float = thaw_rate_per_second * (1.0 + warmth * warm_rate_scale)
		freeze_progress = clampf(freeze_progress - rate * safe_delta, 0.0, 1.0)
	maximum_freeze_progress = max(maximum_freeze_progress, freeze_progress)
	if not is_equal_approx(previous_progress, freeze_progress):
		freeze_progress_changed.emit(freeze_progress, freeze_progress - previous_progress)
	if previous_progress > 0.001 and freeze_progress <= 0.001:
		clear_fracture("Thawed")
		last_source_name = "Thermal thaw"
		thawed.emit(last_source_name)
	if fracture_stress > 0.0 and freeze_progress < 0.45:
		set_fracture_stress(move_toward(fracture_stress, 0.0, passive_stress_recovery_per_second * safe_delta))


func apply_impact(strength: float, source_name: String = "Impact") -> Dictionary:
	var requested: float = max(strength, 0.0)
	last_source_name = source_name
	total_impact_strength += requested
	if is_shattered or freeze_progress < minimum_fracture_progress or requested <= 0.0:
		return {
			"accepted": false,
			"cracked": is_cracked,
			"shattered": is_shattered,
			"stress": fracture_stress,
		}
	var coldness: float = max(freezing_point_c - get_temperature_c(), 0.0)
	var brittleness: float = 1.0 + coldness * cold_brittleness_scale
	var structure_factor: float = lerpf(0.38, 1.0, freeze_progress)
	var added_stress: float = requested * brittleness * structure_factor
	var was_cracked: bool = is_cracked
	set_fracture_stress(fracture_stress + added_stress)
	if not was_cracked and fracture_stress >= crack_threshold:
		is_cracked = true
		cracked.emit(source_name)
	if fracture_stress >= shatter_threshold:
		shatter(source_name)
	return {
		"accepted": true,
		"cracked": is_cracked,
		"shattered": is_shattered,
		"stress": fracture_stress,
		"added_stress": added_stress,
	}


func shatter(source_name: String = "Shatter") -> bool:
	if is_shattered or freeze_progress < minimum_fracture_progress:
		return false
	last_source_name = source_name
	is_shattered = true
	is_cracked = true
	set_fracture_stress(max(fracture_stress, shatter_threshold))
	set_freeze_progress(0.0)
	shattered.emit(source_name)
	return true


func apply_cold_energy(energy_j: float, source_name: String = "Cold") -> float:
	resolve_dependencies()
	if thermal_state == null:
		return 0.0
	last_source_name = source_name
	return thermal_state.apply_energy_j(-absf(energy_j), source_name)


func apply_heat_energy(energy_j: float, source_name: String = "Heat") -> float:
	resolve_dependencies()
	if thermal_state == null:
		return 0.0
	last_source_name = source_name
	return thermal_state.apply_energy_j(absf(energy_j), source_name)


func set_freeze_progress(next_progress: float) -> void:
	var previous: float = freeze_progress
	freeze_progress = clampf(next_progress, 0.0, 1.0)
	maximum_freeze_progress = max(maximum_freeze_progress, freeze_progress)
	if not is_equal_approx(previous, freeze_progress):
		freeze_progress_changed.emit(freeze_progress, freeze_progress - previous)


func set_fracture_stress(next_stress: float) -> void:
	var previous: float = fracture_stress
	fracture_stress = max(next_stress, 0.0)
	if not is_equal_approx(previous, fracture_stress):
		fracture_changed.emit(fracture_stress, fracture_stress - previous)


func clear_fracture(source_name: String = "Clear") -> void:
	last_source_name = source_name
	is_cracked = false
	is_shattered = false
	set_fracture_stress(0.0)


func get_temperature_c() -> float:
	return thermal_state.temperature_c if thermal_state != null else 20.0


func get_initial_progress() -> float:
	if thermal_state == null:
		return 0.0
	if thermal_state.temperature_c <= freezing_point_c:
		return 1.0
	return 0.0


func reset_target() -> void:
	resolve_dependencies()
	is_cracked = false
	is_shattered = false
	fracture_stress = 0.0
	total_impact_strength = 0.0
	last_source_name = "reset"
	freeze_progress = 1.0 if starts_frozen else get_initial_progress()
	maximum_freeze_progress = freeze_progress
	freeze_progress_changed.emit(freeze_progress, 0.0)
	fracture_changed.emit(fracture_stress, 0.0)


func get_debug_data() -> Dictionary:
	return {
		"freeze_state": true,
		"progress": snapped(freeze_progress, 0.001),
		"maximum_progress": snapped(maximum_freeze_progress, 0.001),
		"temperature_c": snapped(get_temperature_c(), 0.1),
		"fracture_stress": snapped(fracture_stress, 0.001),
		"cracked": is_cracked,
		"shattered": is_shattered,
		"total_impact_strength": snapped(total_impact_strength, 0.01),
		"last_source": last_source_name,
	}
