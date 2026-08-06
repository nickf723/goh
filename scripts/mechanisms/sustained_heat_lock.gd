extends MechanismSignalNode
class_name SustainedHeatLock

signal heat_progress_changed(
	temperature_c: float,
	held_seconds: float,
	required_seconds: float,
	progress: float
)
signal heat_requirement_completed

@export_group("Heat Requirement")
@export var thermal_source_path: NodePath
@export var thermal_source_id: String = ""
@export var required_temperature_c: float = 150.0
@export_range(0.05, 20.0, 0.05) var required_hold_seconds: float = 1.5
@export var reset_progress_below_threshold: bool = true
@export var latch_when_completed: bool = true

var held_seconds: float = 0.0
var completed: bool = false
var completion_count: int = 0
var threshold_cross_count: int = 0
var was_above_threshold: bool = false
var last_temperature_c: float = 0.0


func _ready() -> void:
	mirror_active_to_value = false
	minimum_value = 0.0
	maximum_value = 1.0
	value_unit = "progress"
	super._ready()
	set_process(true)
	call_deferred("bind_exported_thermal_source")


func bind_exported_thermal_source() -> bool:
	if thermal_source_path == NodePath():
		return false
	var source: Node = get_node_or_null(thermal_source_path)
	if source == null and get_parent() != null:
		source = get_parent().get_node_or_null(thermal_source_path)
	return bind_source(source)


# The source's Boolean threshold is useful to other mechanism consumers, but it
# must not activate this node by itself. This node owns the additional time
# requirement and publishes only after the heat has remained high long enough.
func _on_source_state_changed(
	_source_id: String,
	_previous_active: bool,
	_next_active: bool,
	_packet: Dictionary
) -> void:
	pass


func _evaluate_source_states() -> void:
	pass


func _process(delta: float) -> void:
	if completed and latch_when_completed:
		return
	var source_id: String = get_primary_source_id(thermal_source_id)
	if source_id == "":
		return
	last_temperature_c = get_source_value(source_id)
	var above_threshold: bool = (
		last_temperature_c >= required_temperature_c
	)
	if above_threshold and not was_above_threshold:
		threshold_cross_count += 1
	was_above_threshold = above_threshold

	if above_threshold:
		held_seconds += maxf(delta, 0.0)
	elif reset_progress_below_threshold:
		held_seconds = 0.0
	else:
		held_seconds = maxf(
			held_seconds - maxf(delta, 0.0),
			0.0
		)

	var required_seconds: float = maxf(required_hold_seconds, 0.05)
	var progress: float = clampf(
		held_seconds / required_seconds,
		0.0,
		1.0
	)
	var just_completed: bool = not completed and progress >= 1.0
	if just_completed:
		completed = true
		completion_count += 1
	var next_active: bool = completed if latch_when_completed else progress >= 1.0
	set_mechanism_state(
		next_active,
		progress,
		{
			"reason": "sustained_heat_update",
			"temperature_c": last_temperature_c,
			"required_temperature_c": required_temperature_c,
			"held_seconds": held_seconds,
			"required_hold_seconds": required_seconds,
			"progress": progress,
			"above_threshold": above_threshold,
			"latched": completed,
		},
		just_completed
	)
	heat_progress_changed.emit(
		last_temperature_c,
		held_seconds,
		required_seconds,
		progress
	)
	if just_completed:
		heat_requirement_completed.emit()


func reset_heat_progress() -> void:
	held_seconds = 0.0
	completed = false
	was_above_threshold = false
	last_temperature_c = 0.0
	set_mechanism_state(false, 0.0, {
		"reason": "heat_progress_reset",
	}, true)


func reset_target() -> void:
	completion_count = 0
	threshold_cross_count = 0
	reset_heat_progress()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["sustained_heat_lock"] = true
	data["temperature_c"] = snappedf(last_temperature_c, 0.01)
	data["required_temperature_c"] = required_temperature_c
	data["held_seconds"] = snappedf(held_seconds, 0.01)
	data["required_hold_seconds"] = required_hold_seconds
	data["progress"] = snappedf(get_mechanism_value(), 0.01)
	data["completed"] = completed
	data["latched"] = latch_when_completed
	data["completion_count"] = completion_count
	data["threshold_crosses"] = threshold_cross_count
	return data
