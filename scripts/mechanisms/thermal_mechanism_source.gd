extends MechanismSignalNode
class_name ThermalMechanismSource

@export_group("Thermal Source")
@export var thermal_state_path: NodePath = NodePath("../ThermalState")
@export var active_threshold_c: float = 0.0
@export var active_when_above_threshold: bool = true

var thermal_state: ThermalState
var update_count: int = 0
var last_temperature_delta_c: float = 0.0
var last_thermal_source: String = "initial"


func _ready() -> void:
	mirror_active_to_value = false
	value_unit = "°C"
	clamp_value_to_range = false
	super._ready()
	call_deferred("bind_exported_thermal_state")


func _exit_tree() -> void:
	unbind_thermal_state()
	super._exit_tree()


func bind_exported_thermal_state() -> bool:
	if thermal_state_path == NodePath():
		return thermal_state != null and is_instance_valid(thermal_state)
	var resolved: ThermalState = get_node_or_null(
		thermal_state_path
	) as ThermalState
	if resolved == null and get_parent() != null:
		resolved = get_parent().get_node_or_null(
			"ThermalState"
		) as ThermalState
	if resolved == null:
		return thermal_state != null and is_instance_valid(thermal_state)
	return bind_thermal_state(resolved)


func bind_thermal_state(next_state: ThermalState) -> bool:
	unbind_thermal_state()
	thermal_state = next_state
	if thermal_state == null or not is_instance_valid(thermal_state):
		return false
	var callback := Callable(self, "_on_temperature_changed")
	if not thermal_state.temperature_changed.is_connected(callback):
		thermal_state.temperature_changed.connect(callback)
	publish_temperature("thermal_bound", true)
	return true


func unbind_thermal_state() -> void:
	if thermal_state != null and is_instance_valid(thermal_state):
		var callback := Callable(self, "_on_temperature_changed")
		if thermal_state.temperature_changed.is_connected(callback):
			thermal_state.temperature_changed.disconnect(callback)
	thermal_state = null


func _on_temperature_changed(
	_temperature_c: float,
	delta_c: float,
	source_name: String
) -> void:
	last_temperature_delta_c = delta_c
	last_thermal_source = source_name
	publish_temperature("temperature_changed", false)


func publish_temperature(
	reason: String = "thermal_update",
	force_emit: bool = false
) -> void:
	var temperature_c: float = get_temperature_c()
	var next_active: bool = (
		temperature_c >= active_threshold_c
		if active_when_above_threshold
		else temperature_c <= active_threshold_c
	)
	update_count += 1
	set_mechanism_state(
		next_active,
		temperature_c,
		{
			"reason": reason,
			"temperature_c": temperature_c,
			"temperature_delta_c": last_temperature_delta_c,
			"thermal_source": last_thermal_source,
			"threshold_c": active_threshold_c,
			"unit": value_unit,
		},
		force_emit
	)


func get_temperature_c() -> float:
	return (
		thermal_state.temperature_c
		if thermal_state != null and is_instance_valid(thermal_state)
		else initial_value
	)


func reset_target() -> void:
	if thermal_state != null and thermal_state.has_method("reset_target"):
		thermal_state.reset_target()
	last_temperature_delta_c = 0.0
	last_thermal_source = "reset"
	publish_temperature("reset", true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["thermal_mechanism_source"] = true
	data["thermal_bound"] = thermal_state != null and is_instance_valid(thermal_state)
	data["temperature_c"] = snappedf(get_temperature_c(), 0.01)
	data["threshold_c"] = active_threshold_c
	data["active_above"] = active_when_above_threshold
	data["temperature_delta_c"] = snappedf(last_temperature_delta_c, 0.01)
	data["thermal_source"] = last_thermal_source
	data["updates"] = update_count
	return data
