extends MechanismSignalNode
class_name MechanismValueComparator

enum Comparison {
	GREATER_THAN,
	GREATER_OR_EQUAL,
	LESS_THAN,
	LESS_OR_EQUAL,
	EQUAL_WITHIN_TOLERANCE,
	INSIDE_RANGE,
	OUTSIDE_RANGE,
	SOURCES_WITHIN_TOLERANCE,
}

@export_group("Comparison")
@export var comparison: Comparison = Comparison.GREATER_OR_EQUAL
@export var primary_source_id: String = ""
@export var secondary_source_id: String = ""
@export var use_normalized_values: bool = false
@export var require_all_sources_active: bool = false
@export var threshold: float = 1.0
@export var range_minimum: float = 0.0
@export var range_maximum: float = 1.0
@export_range(0.0, 10000.0, 0.001) var tolerance: float = 0.1
@export var invert_result: bool = false

var last_primary_value: float = 0.0
var last_secondary_value: float = 0.0
var last_difference: float = 0.0
var evaluation_count: int = 0
var last_comparison_summary: String = "uninitialized"


func _ready() -> void:
	evaluate_sources_as_or = false
	mirror_active_to_value = false
	super._ready()


func _on_sources_ready() -> void:
	_evaluate_source_states()


func _on_source_state_changed(
	_source_id: String,
	_previous_active: bool,
	_next_active: bool,
	_packet: Dictionary
) -> void:
	_evaluate_source_states()


func _evaluate_source_states() -> void:
	var primary_id: String = get_primary_source_id(primary_source_id)
	if primary_id == "":
		last_comparison_summary = "missing primary source"
		set_mechanism_state(false, 0.0, {
			"reason": "value_comparison_missing_source",
			"comparison": get_comparison_name(),
		}, true)
		return

	var secondary_id: String = _resolve_secondary_source_id(primary_id)
	last_primary_value = _read_comparison_value(primary_id)
	last_secondary_value = (
		_read_comparison_value(secondary_id)
		if secondary_id != ""
		else 0.0
	)
	last_difference = last_primary_value - last_secondary_value
	evaluation_count += 1

	var result: bool = false
	var result_value: float = last_primary_value
	match comparison:
		Comparison.GREATER_THAN:
			result = last_primary_value > threshold
		Comparison.GREATER_OR_EQUAL:
			result = last_primary_value >= threshold
		Comparison.LESS_THAN:
			result = last_primary_value < threshold
		Comparison.LESS_OR_EQUAL:
			result = last_primary_value <= threshold
		Comparison.EQUAL_WITHIN_TOLERANCE:
			result = absf(last_primary_value - threshold) <= tolerance
		Comparison.INSIDE_RANGE:
			result = _is_inside_range(last_primary_value)
		Comparison.OUTSIDE_RANGE:
			result = not _is_inside_range(last_primary_value)
		Comparison.SOURCES_WITHIN_TOLERANCE:
			result_value = last_difference
			result = (
				secondary_id != ""
				and absf(last_difference) <= tolerance
			)

	if invert_result:
		result = not result
	if require_all_sources_active:
		result = (
			result
			and get_source_state(primary_id)
			and (
				secondary_id == ""
				or get_source_state(secondary_id)
			)
		)

	last_comparison_summary = _build_comparison_summary(
		primary_id,
		secondary_id,
		result
	)
	set_mechanism_state(result, result_value, {
		"reason": "value_comparison",
		"comparison": get_comparison_name(),
		"primary_source_id": primary_id,
		"secondary_source_id": secondary_id,
		"primary_value": last_primary_value,
		"secondary_value": last_secondary_value,
		"difference": last_difference,
		"threshold": threshold,
		"range_minimum": minf(range_minimum, range_maximum),
		"range_maximum": maxf(range_minimum, range_maximum),
		"tolerance": tolerance,
		"normalized_inputs": use_normalized_values,
		"require_all_sources_active": require_all_sources_active,
		"primary_active": get_source_state(primary_id),
		"secondary_active": (
			get_source_state(secondary_id)
			if secondary_id != ""
			else false
		),
		"inverted": invert_result,
		"summary": last_comparison_summary,
	})


func _read_comparison_value(source_id: String) -> float:
	if use_normalized_values:
		return get_source_normalized_value(source_id)
	return get_source_value(source_id)


func _resolve_secondary_source_id(primary_id: String) -> String:
	var configured: String = _normalize_id(secondary_source_id)
	if configured != "" and configured != primary_id and source_nodes.has(configured):
		return configured
	for source_id: String in get_bound_source_ids():
		if source_id != primary_id:
			return source_id
	return ""


func _is_inside_range(source_value: float) -> bool:
	var minimum: float = minf(range_minimum, range_maximum)
	var maximum: float = maxf(range_minimum, range_maximum)
	return source_value >= minimum and source_value <= maximum


func _build_comparison_summary(
	primary_id: String,
	secondary_id: String,
	result: bool
) -> String:
	var state_text: String = "ON" if result else "OFF"
	match comparison:
		Comparison.SOURCES_WITHIN_TOLERANCE:
			return (
				primary_id
				+ " − "
				+ secondary_id
				+ " = "
				+ str(snappedf(last_difference, 0.01))
				+ " ± "
				+ str(snappedf(tolerance, 0.01))
				+ " → "
				+ state_text
			)
		Comparison.INSIDE_RANGE, Comparison.OUTSIDE_RANGE:
			return (
				primary_id
				+ " = "
				+ str(snappedf(last_primary_value, 0.01))
				+ " range "
				+ str(snappedf(minf(range_minimum, range_maximum), 0.01))
				+ "…"
				+ str(snappedf(maxf(range_minimum, range_maximum), 0.01))
				+ " → "
				+ state_text
			)
		_:
			return (
				primary_id
				+ " = "
				+ str(snappedf(last_primary_value, 0.01))
				+ " vs "
				+ str(snappedf(threshold, 0.01))
				+ " → "
				+ state_text
			)


func get_comparison_name() -> String:
	return Comparison.keys()[comparison].to_lower()


func reset_target() -> void:
	last_primary_value = 0.0
	last_secondary_value = 0.0
	last_difference = 0.0
	evaluation_count = 0
	last_comparison_summary = "reset"
	super.reset_target()
	_evaluate_source_states()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["value_comparator"] = true
	data["comparison"] = get_comparison_name()
	data["primary_source_id"] = get_primary_source_id(primary_source_id)
	data["secondary_source_id"] = _resolve_secondary_source_id(
		get_primary_source_id(primary_source_id)
	)
	data["primary_value"] = last_primary_value
	data["secondary_value"] = last_secondary_value
	data["difference"] = last_difference
	data["threshold"] = threshold
	data["range_minimum"] = minf(range_minimum, range_maximum)
	data["range_maximum"] = maxf(range_minimum, range_maximum)
	data["tolerance"] = tolerance
	data["normalized_inputs"] = use_normalized_values
	data["require_all_sources_active"] = require_all_sources_active
	data["evaluations"] = evaluation_count
	data["summary"] = last_comparison_summary
	return data
