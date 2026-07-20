extends Node
class_name CombustionState

signal combustion_state_changed(previous_state: String, next_state: String)
signal intensity_changed(intensity: float)
signal fuel_changed(fuel_kg: float, consumed_kg: float)
signal extinguished(source_name: String)

const STATE_COLD: String = "cold"
const STATE_HEATING: String = "heating"
const STATE_BURNING: String = "burning"
const STATE_SMOLDERING: String = "smoldering"
const STATE_EXTINGUISHED: String = "extinguished"
const STATE_SPENT: String = "spent"

@export var enabled: bool = true
@export var material_profile: PhysicalMaterialProfile
@export var thermal_state_path: NodePath
@export var starts_ignited: bool = false

@export_group("Authored Overrides")
@export var combustible_override: bool = false
@export var initial_fuel_kg_override: float = 0.0
@export var ignition_temperature_c_override: float = 0.0
@export var sustain_temperature_c_override: float = 0.0
@export var burn_rate_kg_per_second_override: float = 0.0
@export var heat_output_j_per_second_override: float = 0.0
@export_range(0.0, 1.0, 0.01) var smoke_yield_override: float = 0.0
@export_range(0.0, 1.0, 0.01) var ember_yield_override: float = 0.0

@export_group("Behavior")
@export_range(0.0, 1.0, 0.01) var oxygen_factor: float = 1.0
@export_range(0.01, 0.5, 0.01) var smolder_fuel_ratio: float = 0.16
@export var extinguish_recovery_per_second: float = 0.18
@export var passive_smolder_burn_scale: float = 0.16
@export var auto_process: bool = true

var thermal_state: ThermalState
var fuel_kg: float = 0.0
var starting_fuel_kg: float = 0.0
var state: String = STATE_COLD
var burning: bool = false
var burn_intensity: float = 0.0
var extinguish_saturation: float = 0.0
var airflow_velocity: Vector3 = Vector3.ZERO
var last_source_name: String = "initial"
var total_consumed_kg: float = 0.0
var total_heat_output_j: float = 0.0


func _ready() -> void:
	resolve_dependencies()
	starting_fuel_kg = max(get_initial_fuel_kg(), 0.0)
	fuel_kg = starting_fuel_kg
	burning = starts_ignited and can_combust() and fuel_kg > 0.0
	state = STATE_BURNING if burning else STATE_COLD
	add_to_group("combustion_states")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	publish_state()


func _process(delta: float) -> void:
	if auto_process:
		step_combustion(delta)


func configure(
	next_thermal_state: ThermalState,
	next_material_profile: PhysicalMaterialProfile = null,
	next_fuel_kg: float = -1.0
) -> void:
	thermal_state = next_thermal_state
	if next_material_profile != null:
		material_profile = next_material_profile
	if next_fuel_kg >= 0.0:
		initial_fuel_kg_override = next_fuel_kg
	starting_fuel_kg = max(get_initial_fuel_kg(), 0.0)
	fuel_kg = starting_fuel_kg


func resolve_dependencies() -> void:
	if thermal_state != null:
		return
	if not thermal_state_path.is_empty():
		thermal_state = get_node_or_null(thermal_state_path) as ThermalState
	if thermal_state == null:
		thermal_state = get_parent().get_node_or_null("ThermalState") as ThermalState
	if material_profile == null and thermal_state != null:
		material_profile = thermal_state.material_profile


func step_combustion(delta: float) -> void:
	var safe_delta: float = max(delta, 0.0)
	resolve_dependencies()
	if not enabled or not can_combust():
		set_burning(false, "Disabled")
		set_intensity(0.0)
		set_state(STATE_COLD)
		return
	if finish_if_spent():
		return

	extinguish_saturation = max(extinguish_saturation - extinguish_recovery_per_second * safe_delta, 0.0)
	var temperature_c: float = get_temperature_c()
	var ignition_c: float = get_ignition_temperature_c()
	var sustain_c: float = get_sustain_temperature_c()

	if not burning and temperature_c >= ignition_c and extinguish_saturation < 0.9:
		set_burning(true, "Thermal ignition")

	if burning and (temperature_c < sustain_c or extinguish_saturation >= 1.0):
		set_burning(false, "Cooling")
		if temperature_c >= sustain_c * 0.72 and fuel_kg > 0.0:
			set_state(STATE_SMOLDERING)
		else:
			set_state(STATE_EXTINGUISHED)

	if burning:
		var thermal_span: float = max(ignition_c - sustain_c, 1.0)
		var thermal_factor: float = clampf((temperature_c - sustain_c) / thermal_span, 0.0, 1.0)
		var airflow_factor: float = clampf(1.0 + airflow_velocity.length() * 0.08, 0.5, 1.8)
		var next_intensity: float = clampf((0.34 + thermal_factor * 0.66) * oxygen_factor * airflow_factor, 0.05, 1.5)
		var fuel_ratio: float = get_fuel_ratio()
		if fuel_ratio <= smolder_fuel_ratio:
			set_state(STATE_SMOLDERING)
			next_intensity *= clampf(fuel_ratio / max(smolder_fuel_ratio, 0.01), 0.12, 0.42)
		else:
			set_state(STATE_BURNING)
		set_intensity(next_intensity)
		consume_fuel(get_burn_rate_kg_per_second() * burn_intensity * safe_delta)
		if finish_if_spent():
			return
		apply_combustion_heat(get_heat_output_j_per_second() * burn_intensity * safe_delta)
	else:
		set_intensity(move_toward(burn_intensity, 0.0, safe_delta * 2.8))
		if state == STATE_SMOLDERING and get_temperature_c() >= sustain_c * 0.68:
			var smolder_amount: float = get_burn_rate_kg_per_second() * passive_smolder_burn_scale * safe_delta
			consume_fuel(smolder_amount)
			if finish_if_spent():
				return
			apply_combustion_heat(get_heat_output_j_per_second() * passive_smolder_burn_scale * safe_delta)
		elif get_temperature_c() < sustain_c * 0.55 and state not in [STATE_EXTINGUISHED, STATE_SPENT]:
			set_state(STATE_HEATING if get_temperature_c() > 40.0 else STATE_COLD)


func finish_if_spent() -> bool:
	if fuel_kg > 0.00001:
		return false
	fuel_kg = 0.0
	set_burning(false, "Fuel spent")
	set_intensity(0.0)
	set_state(STATE_SPENT)
	return true


func force_ignite(source_name: String = "Ignition") -> bool:
	resolve_dependencies()
	if not can_combust() or fuel_kg <= 0.0:
		return false
	last_source_name = source_name
	if thermal_state != null and thermal_state.temperature_c < get_ignition_temperature_c():
		thermal_state.set_temperature(get_ignition_temperature_c(), source_name)
	set_burning(true, source_name)
	set_state(STATE_BURNING)
	set_intensity(max(burn_intensity, 0.45))
	return true


func apply_extinguish(
	strength: float,
	cooling_energy_j: float = 0.0,
	source_name: String = "Extinguish"
) -> bool:
	var applied_strength: float = max(strength, 0.0)
	last_source_name = source_name
	extinguish_saturation = clampf(extinguish_saturation + applied_strength, 0.0, 2.0)
	if thermal_state != null and cooling_energy_j > 0.0:
		thermal_state.apply_energy_j(-cooling_energy_j, source_name)
	var was_burning: bool = burning
	if extinguish_saturation >= 1.0:
		set_burning(false, source_name)
		set_intensity(0.0)
		set_state(STATE_EXTINGUISHED if fuel_kg > 0.0 else STATE_SPENT)
		if was_burning:
			extinguished.emit(source_name)
	return was_burning and not burning


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var element: String = payload.element.to_lower().strip_edges()
	var normalized_tags: Array[String] = []
	for raw_tag: String in payload.tags:
		normalized_tags.append(raw_tag.to_lower().strip_edges())
	if element == "water" or "water" in normalized_tags or "extinguish" in normalized_tags or "douse" in normalized_tags:
		var strength: float = max(float(abs(payload.amount)) * 0.35, payload.status_strength, 0.4)
		var stopped: bool = apply_extinguish(strength, 120.0 * strength, payload.source_name)
		return {
			"message": payload.source_name + (" extinguishes " if stopped else " cools ") + get_parent().name + ".",
			"objective": "Observe flame, smoke, fuel, and temperature respond to water.",
			"combustion_state": state,
		}
	if element == "ice" or "cold" in normalized_tags or "freeze" in normalized_tags:
		apply_extinguish(0.55, 0.0, payload.source_name)
	if element == "fire" or "heat" in normalized_tags or "ignite" in normalized_tags:
		last_source_name = payload.source_name
	return {
		"combustion_state": state,
		"burn_intensity": burn_intensity,
		"fuel_kg": fuel_kg,
	}


func consume_fuel(amount_kg: float) -> float:
	var requested: float = max(amount_kg, 0.0)
	if requested <= 0.0 or fuel_kg <= 0.0:
		return 0.0
	var consumed: float = min(requested, fuel_kg)
	fuel_kg -= consumed
	total_consumed_kg += consumed
	fuel_changed.emit(fuel_kg, consumed)
	return consumed


func apply_combustion_heat(energy_j: float) -> float:
	if thermal_state == null or energy_j <= 0.0:
		return 0.0
	total_heat_output_j += energy_j
	thermal_state.apply_energy_j(energy_j, "Combustion")
	return energy_j


func set_airflow(next_airflow_velocity: Vector3) -> void:
	if next_airflow_velocity.is_finite():
		airflow_velocity = next_airflow_velocity


func set_burning(next_burning: bool, source_name: String) -> void:
	burning = next_burning and fuel_kg > 0.0 and can_combust()
	last_source_name = source_name


func set_state(next_state: String) -> void:
	if state == next_state:
		return
	var previous: String = state
	state = next_state
	combustion_state_changed.emit(previous, state)


func set_intensity(next_intensity: float) -> void:
	var clamped: float = clampf(next_intensity, 0.0, 1.5)
	if is_equal_approx(clamped, burn_intensity):
		return
	burn_intensity = clamped
	intensity_changed.emit(burn_intensity)


func publish_state() -> void:
	combustion_state_changed.emit("initial", state)
	intensity_changed.emit(burn_intensity)
	fuel_changed.emit(fuel_kg, 0.0)


func can_combust() -> bool:
	if combustible_override:
		return true
	return material_profile != null and material_profile.is_combustible()


func get_initial_fuel_kg() -> float:
	if initial_fuel_kg_override > 0.0:
		return initial_fuel_kg_override
	if material_profile != null:
		return max(material_profile.default_fuel_mass_kg, 0.0)
	return 0.0


func get_ignition_temperature_c() -> float:
	if ignition_temperature_c_override > 0.0:
		return ignition_temperature_c_override
	if material_profile != null:
		return material_profile.ignition_temperature_c
	if thermal_state != null:
		return thermal_state.get_ignition_temperature_c()
	return 180.0


func get_sustain_temperature_c() -> float:
	if sustain_temperature_c_override > 0.0:
		return sustain_temperature_c_override
	if material_profile != null:
		return material_profile.sustain_temperature_c
	return get_ignition_temperature_c() * 0.65


func get_burn_rate_kg_per_second() -> float:
	if burn_rate_kg_per_second_override > 0.0:
		return burn_rate_kg_per_second_override
	if material_profile != null:
		return max(material_profile.burn_rate_kg_per_second, 0.0)
	return 0.02


func get_heat_output_j_per_second() -> float:
	if heat_output_j_per_second_override > 0.0:
		return heat_output_j_per_second_override
	if material_profile != null:
		return max(material_profile.combustion_heat_j_per_second, 0.0)
	return 30.0


func get_smoke_yield() -> float:
	if smoke_yield_override > 0.0:
		return smoke_yield_override
	if material_profile != null:
		return material_profile.smoke_yield
	return 0.5


func get_ember_yield() -> float:
	if ember_yield_override > 0.0:
		return ember_yield_override
	if material_profile != null:
		return material_profile.ember_yield
	return 0.35


func get_temperature_c() -> float:
	return thermal_state.temperature_c if thermal_state != null else 20.0


func get_fuel_ratio() -> float:
	if starting_fuel_kg <= 0.0:
		return 0.0
	return clampf(fuel_kg / starting_fuel_kg, 0.0, 1.0)


func reset_target() -> void:
	resolve_dependencies()
	fuel_kg = max(starting_fuel_kg, get_initial_fuel_kg())
	total_consumed_kg = 0.0
	total_heat_output_j = 0.0
	extinguish_saturation = 0.0
	burn_intensity = 0.0
	burning = starts_ignited and can_combust() and fuel_kg > 0.0
	state = STATE_BURNING if burning else STATE_COLD
	airflow_velocity = Vector3.ZERO
	last_source_name = "reset"
	publish_state()


func get_visual_state() -> Dictionary:
	return {
		"state": state,
		"burning": burning,
		"intensity": burn_intensity,
		"fuel_ratio": get_fuel_ratio(),
		"smoke": get_smoke_yield() * (0.35 + burn_intensity),
		"embers": get_ember_yield() * burn_intensity,
		"airflow": airflow_velocity,
		"temperature_c": get_temperature_c(),
	}


func get_debug_data() -> Dictionary:
	return {
		"combustion_state": true,
		"state": state,
		"burning": burning,
		"burn_intensity": snapped(burn_intensity, 0.01),
		"fuel_kg": snapped(fuel_kg, 0.001),
		"fuel_ratio": snapped(get_fuel_ratio(), 0.01),
		"temperature_c": snapped(get_temperature_c(), 0.1),
		"ignition_temperature_c": snapped(get_ignition_temperature_c(), 0.1),
		"sustain_temperature_c": snapped(get_sustain_temperature_c(), 0.1),
		"extinguish_saturation": snapped(extinguish_saturation, 0.01),
		"airflow": airflow_velocity,
		"consumed_kg": snapped(total_consumed_kg, 0.001),
		"heat_output_j": snapped(total_heat_output_j, 0.01),
		"last_source": last_source_name,
	}
