extends Node
class_name StructuralIntegrity

signal integrity_changed(stress_n: float, capacity_n: float)
signal integrity_failed(reason: String, peak_stress_n: float)

@export var material_profile: StructuralMaterialProfile
@export var thermal_state_path: NodePath = NodePath("../ThermalState")
@export var combustion_state_path: NodePath = NodePath("../CombustionState")
@export_range(0.0, 10000.0, 1.0) var transient_stress_decay_n_per_second: float = 1900.0

var sustained_stress_n: float = 0.0
var transient_stress_n: float = 0.0
var peak_stress_n: float = 0.0
var damage_fraction: float = 0.0
var burn_fraction: float = 0.0
var overload_timer: float = 0.0
var failed: bool = false
var failure_reason: String = ""
var last_source_name: String = "initial"
var thermal_state: Node = null
var combustion_state: Node = null


func _ready() -> void:
	resolve_dependencies()
	add_to_group("structural_integrity")
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func _physics_process(delta: float) -> void:
	step_integrity(delta)


func resolve_dependencies() -> void:
	if thermal_state == null and not thermal_state_path.is_empty():
		thermal_state = get_node_or_null(thermal_state_path)
	if combustion_state == null and not combustion_state_path.is_empty():
		combustion_state = get_node_or_null(combustion_state_path)


func step_integrity(delta: float) -> void:
	if failed or material_profile == null:
		return
	resolve_dependencies()
	var safe_delta: float = maxf(delta, 0.0)
	if is_combustion_burning():
		burn_fraction = clampf(
			burn_fraction
			+ material_profile.burn_weakening_per_second
			* get_combustion_intensity()
			* safe_delta,
			0.0,
			1.0
		)
	transient_stress_n = maxf(
		transient_stress_n
		- transient_stress_decay_n_per_second * safe_delta,
		0.0
	)
	evaluate_failure(safe_delta)


func set_sustained_stress(stress_n: float, source_name: String = "supported load") -> void:
	if failed:
		return
	sustained_stress_n = maxf(stress_n, 0.0)
	last_source_name = source_name


func apply_transient_stress(stress_n: float, source_name: String = "impact") -> void:
	if failed:
		return
	transient_stress_n += maxf(stress_n, 0.0)
	last_source_name = source_name
	evaluate_failure(0.0)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null or material_profile == null or failed:
		return {}
	var payload_points: float = maxf(
		float(maxi(payload.amount, 0)),
		float(maxi(payload.stance_damage, 0))
	)
	damage_fraction = clampf(
		damage_fraction
		+ payload_points * material_profile.damage_per_payload_point,
		0.0,
		1.0
	)
	var payload_stress_n: float = material_profile.get_payload_stress(payload)
	apply_transient_stress(payload_stress_n, payload.source_name)
	return {
		"message": (
			payload.source_name
			+ " loads "
			+ get_parent().name
			+ " to "
			+ str(int(round(get_total_stress_n())))
			+ " / "
			+ str(int(round(get_effective_capacity_n())))
			+ " N."
		),
		"objective": "Break supports with force, heat, brittleness, or sustained load.",
		"structural_stress_n": get_total_stress_n(),
		"structural_capacity_n": get_effective_capacity_n(),
		"failed": failed,
	}


func apply_fire_exposure(amount: float, source_name: String = "fire") -> void:
	if material_profile == null or not material_profile.burnable or failed:
		return
	burn_fraction = clampf(burn_fraction + maxf(amount, 0.0), 0.0, 1.0)
	last_source_name = source_name
	evaluate_failure(0.0)


func evaluate_failure(delta: float) -> void:
	if failed or material_profile == null:
		return
	var stress_n: float = get_total_stress_n()
	var capacity_n: float = get_effective_capacity_n()
	peak_stress_n = maxf(peak_stress_n, stress_n)
	integrity_changed.emit(stress_n, capacity_n)
	if stress_n <= capacity_n:
		overload_timer = 0.0
		return
	overload_timer += maxf(delta, 0.0)
	if delta <= 0.0 or overload_timer >= material_profile.overload_grace_seconds:
		fail_integrity(get_failure_reason(), stress_n)


func get_failure_reason() -> String:
	if material_profile != null and material_profile.burnable and burn_fraction >= 0.15:
		return "burn weakened"
	if is_brittle():
		return "brittle fracture"
	if transient_stress_n > sustained_stress_n:
		return "impact overload"
	return "load overload"


func fail_integrity(reason: String, stress_n: float = -1.0) -> void:
	if failed:
		return
	failed = true
	failure_reason = reason
	var resolved_stress_n: float = get_total_stress_n() if stress_n < 0.0 else stress_n
	peak_stress_n = maxf(peak_stress_n, resolved_stress_n)
	integrity_failed.emit(failure_reason, peak_stress_n)


func get_total_stress_n() -> float:
	return maxf(sustained_stress_n + transient_stress_n, 0.0)


func get_effective_capacity_n() -> float:
	if material_profile == null:
		return 1.0
	return material_profile.get_effective_capacity(
		damage_fraction,
		burn_fraction,
		is_brittle()
	)


func is_brittle() -> bool:
	if material_profile == null or thermal_state == null:
		return false
	return float(thermal_state.get("temperature_c")) <= material_profile.brittle_temperature_c


func is_combustion_burning() -> bool:
	return combustion_state != null and bool(combustion_state.get("burning"))


func get_combustion_intensity() -> float:
	if combustion_state == null:
		return 0.0
	return maxf(float(combustion_state.get("burn_intensity")), 0.1)


func reset_integrity() -> void:
	sustained_stress_n = 0.0
	transient_stress_n = 0.0
	peak_stress_n = 0.0
	damage_fraction = 0.0
	burn_fraction = 0.0
	overload_timer = 0.0
	failed = false
	failure_reason = ""
	last_source_name = "reset"


func reset_target() -> void:
	reset_integrity()


func get_debug_data() -> Dictionary:
	return {
		"structural_integrity": true,
		"stress_n": snapped(get_total_stress_n(), 0.1),
		"sustained_n": snapped(sustained_stress_n, 0.1),
		"transient_n": snapped(transient_stress_n, 0.1),
		"capacity_n": snapped(get_effective_capacity_n(), 0.1),
		"peak_n": snapped(peak_stress_n, 0.1),
		"damage": snapped(damage_fraction, 0.01),
		"burn": snapped(burn_fraction, 0.01),
		"brittle": is_brittle(),
		"failed": failed,
		"reason": failure_reason,
		"source": last_source_name,
	}
