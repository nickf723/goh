extends MechanismSignalNode
class_name MechanismLogicNode

enum Operation {
	PASS,
	AND,
	OR,
	NOT,
	XOR,
	TIMER,
	LATCH,
	COUNTER,
	TOGGLE,
	SET_RESET,
	SEQUENCE,
}

enum SequenceWrongInputBehavior {
	RESET,
	IGNORE,
	RESTART_IF_FIRST,
}

@export_group("Logic")
@export var operation: Operation = Operation.AND
@export_range(0.05, 30.0, 0.05) var timer_seconds: float = 4.0
@export_range(1, 99, 1) var counter_target: int = 3
@export var counter_wraps: bool = false
@export var latch_resets_when_all_sources_inactive: bool = false

@export_group("Memory")
@export var set_source_ids: Array[String] = []
@export var reset_source_ids: Array[String] = []
@export var reset_dominates_set: bool = true
@export var sequence_source_ids: Array[String] = []
@export var sequence_wrong_input_behavior: SequenceWrongInputBehavior = (
	SequenceWrongInputBehavior.RESET
)

var timer_remaining: float = 0.0
var counter_value: int = 0
var latched_active: bool = false
var memory_active: bool = false
var sequence_index: int = 0
var sequence_history: Array[String] = []
var sequence_input_count: int = 0
var sequence_wrong_input_count: int = 0
var memory_transition_count: int = 0
var last_memory_event: String = "none"
var rising_edge_count: int = 0


func _ready() -> void:
	evaluate_sources_as_or = false
	super._ready()
	set_process(false)


func _process(delta: float) -> void:
	if operation != Operation.TIMER or timer_remaining <= 0.0:
		set_process(false)
		return
	timer_remaining = maxf(timer_remaining - delta, 0.0)
	if timer_remaining > 0.0:
		return
	set_process(false)
	set_mechanism_active(false, {
		"reason": "timer_expired",
		"duration": timer_seconds,
	})


func _on_sources_ready() -> void:
	match operation:
		Operation.LATCH:
			latched_active = active
		Operation.COUNTER:
			if active:
				counter_value = counter_target
		Operation.TOGGLE:
			memory_active = active
		Operation.SET_RESET:
			memory_active = active
			if _any_configured_source_active(reset_source_ids):
				memory_active = false
			elif _any_configured_source_active(set_source_ids):
				memory_active = true
		Operation.SEQUENCE:
			memory_active = active
			sequence_index = (
				get_normalized_sequence_source_ids().size()
				if memory_active
				else 0
			)


func _on_source_state_changed(
	source_id: String,
	previous_active: bool,
	next_active: bool,
	packet: Dictionary
) -> void:
	var rising: bool = not previous_active and next_active
	if rising:
		rising_edge_count += 1
	match operation:
		Operation.TIMER:
			if rising:
				trigger_timer(packet)
		Operation.LATCH:
			if next_active:
				latched_active = true
			elif latch_resets_when_all_sources_inactive and get_active_source_count() <= 0:
				latched_active = false
			set_mechanism_active(latched_active, {
				"reason": "latch",
				"source_id": source_id,
				"latched": latched_active,
			})
		Operation.COUNTER:
			if rising:
				counter_value += 1
				if counter_wraps and counter_value > counter_target:
					counter_value = 1
			set_mechanism_active(counter_value >= counter_target, {
				"reason": "counter",
				"source_id": source_id,
				"counter": counter_value,
				"target": counter_target,
			})
		Operation.TOGGLE:
			if rising:
				_apply_memory_state(
					not memory_active,
					"toggle",
					source_id,
					packet
				)
		Operation.SET_RESET:
			if rising:
				_handle_set_reset_rising(source_id, packet)
		Operation.SEQUENCE:
			if rising:
				_handle_sequence_rising(source_id, packet)
		_:
			_evaluate_source_states()


func _evaluate_source_states() -> void:
	var source_count: int = source_states.size()
	var active_count: int = get_active_source_count()
	var next_active: bool = false
	match operation:
		Operation.PASS:
			next_active = active_count > 0
		Operation.AND:
			next_active = source_count > 0 and active_count == source_count
		Operation.OR:
			next_active = active_count > 0
		Operation.NOT:
			next_active = active_count == 0
		Operation.XOR:
			next_active = active_count == 1
		Operation.TIMER:
			next_active = timer_remaining > 0.0
		Operation.LATCH:
			next_active = latched_active
		Operation.COUNTER:
			next_active = counter_value >= counter_target
		Operation.TOGGLE, Operation.SET_RESET, Operation.SEQUENCE:
			next_active = memory_active
	set_mechanism_active(next_active, {
		"reason": "logic_evaluation",
		"operation": get_operation_name(),
		"active_sources": active_count,
		"source_count": source_count,
		"counter": counter_value,
		"counter_target": counter_target,
		"timer_remaining": timer_remaining,
		"memory_active": memory_active,
		"sequence_index": sequence_index,
		"sequence_length": get_normalized_sequence_source_ids().size(),
	})


func trigger_timer(packet: Dictionary = {}) -> void:
	timer_remaining = maxf(timer_seconds, 0.05)
	var timer_packet: Dictionary = packet.duplicate(true)
	timer_packet["reason"] = "timer_triggered"
	timer_packet["duration"] = timer_remaining
	set_mechanism_active(true, timer_packet, true)
	set_process(true)


func _handle_set_reset_rising(source_id: String, packet: Dictionary) -> void:
	var normalized_source_id: String = _normalize_memory_id(source_id)
	var configured_set_ids: Array[String] = _normalized_memory_ids(set_source_ids)
	var configured_reset_ids: Array[String] = _normalized_memory_ids(reset_source_ids)
	var is_set_source: bool = configured_set_ids.has(normalized_source_id)
	var is_reset_source: bool = configured_reset_ids.has(normalized_source_id)

	if is_reset_source:
		_apply_memory_state(false, "reset_input", normalized_source_id, packet)
		return
	if is_set_source:
		if reset_dominates_set and _any_configured_source_active(reset_source_ids):
			_apply_memory_state(false, "set_blocked_by_reset", normalized_source_id, packet)
		else:
			_apply_memory_state(true, "set_input", normalized_source_id, packet)
		return

	var ignored_packet: Dictionary = packet.duplicate(true)
	ignored_packet["reason"] = "unassigned_memory_input"
	ignored_packet["source_id"] = normalized_source_id
	ignored_packet["set_source_ids"] = configured_set_ids
	ignored_packet["reset_source_ids"] = configured_reset_ids
	last_memory_event = "unassigned_memory_input"
	set_mechanism_active(memory_active, ignored_packet, true)


func _handle_sequence_rising(source_id: String, packet: Dictionary) -> void:
	var normalized_source_id: String = _normalize_memory_id(source_id)
	var sequence: Array[String] = get_normalized_sequence_source_ids()
	sequence_input_count += 1

	if sequence.is_empty():
		_emit_sequence_progress(
			"sequence_unconfigured",
			normalized_source_id,
			packet
		)
		return
	if memory_active:
		_emit_sequence_progress(
			"sequence_already_complete",
			normalized_source_id,
			packet
		)
		return

	var expected_source_id: String = sequence[clampi(sequence_index, 0, sequence.size() - 1)]
	if normalized_source_id == expected_source_id:
		sequence_history.append(normalized_source_id)
		sequence_index += 1
		if sequence_index >= sequence.size():
			_apply_memory_state(
				true,
				"sequence_complete",
				normalized_source_id,
				packet
			)
		else:
			_emit_sequence_progress(
				"sequence_advanced",
				normalized_source_id,
				packet
			)
		return

	sequence_wrong_input_count += 1
	match sequence_wrong_input_behavior:
		SequenceWrongInputBehavior.IGNORE:
			pass
		SequenceWrongInputBehavior.RESTART_IF_FIRST:
			if normalized_source_id == sequence[0]:
				sequence_index = 1
				sequence_history = [normalized_source_id]
			else:
				sequence_index = 0
				sequence_history.clear()
		_:
			sequence_index = 0
			sequence_history.clear()
	_emit_sequence_progress(
		"sequence_wrong_input",
		normalized_source_id,
		packet
	)


func _apply_memory_state(
	next_active: bool,
	reason: String,
	source_id: String = "",
	packet: Dictionary = {}
) -> void:
	var changed: bool = memory_active != next_active
	memory_active = next_active
	if changed:
		memory_transition_count += 1
	last_memory_event = reason
	var memory_packet: Dictionary = packet.duplicate(true)
	memory_packet["reason"] = reason
	memory_packet["source_id"] = _normalize_memory_id(source_id)
	memory_packet["memory_active"] = memory_active
	memory_packet["memory_transitions"] = memory_transition_count
	memory_packet["sequence_index"] = sequence_index
	memory_packet["sequence_length"] = get_normalized_sequence_source_ids().size()
	memory_packet["expected_source_id"] = get_expected_sequence_source_id()
	set_mechanism_active(memory_active, memory_packet, true)


func _emit_sequence_progress(
	reason: String,
	source_id: String,
	packet: Dictionary = {}
) -> void:
	last_memory_event = reason
	var sequence_packet: Dictionary = packet.duplicate(true)
	sequence_packet["reason"] = reason
	sequence_packet["source_id"] = _normalize_memory_id(source_id)
	sequence_packet["memory_active"] = memory_active
	sequence_packet["sequence_index"] = sequence_index
	sequence_packet["sequence_length"] = get_normalized_sequence_source_ids().size()
	sequence_packet["sequence_history"] = sequence_history.duplicate()
	sequence_packet["expected_source_id"] = get_expected_sequence_source_id()
	sequence_packet["wrong_inputs"] = sequence_wrong_input_count
	sequence_packet["wrong_input_behavior"] = get_sequence_wrong_input_behavior_name()
	set_mechanism_active(memory_active, sequence_packet, true)


func reset_latch() -> void:
	latched_active = false
	set_mechanism_active(false, {"reason": "latch_reset"}, true)


func reset_counter() -> void:
	counter_value = 0
	set_mechanism_active(false, {
		"reason": "counter_reset",
		"counter": counter_value,
		"target": counter_target,
	}, true)


func set_counter_value(value: int) -> void:
	counter_value = maxi(value, 0)
	_evaluate_source_states()


func set_memory_active(value: bool, reason: String = "manual_memory_set") -> void:
	_apply_memory_state(value, reason)
	if operation == Operation.SEQUENCE:
		sequence_index = (
			get_normalized_sequence_source_ids().size()
			if value
			else 0
		)
		if not value:
			sequence_history.clear()


func reset_memory() -> void:
	memory_active = false
	sequence_index = 0
	sequence_history.clear()
	last_memory_event = "memory_reset"
	set_mechanism_active(false, {
		"reason": "memory_reset",
		"memory_active": false,
		"sequence_index": 0,
		"sequence_length": get_normalized_sequence_source_ids().size(),
	}, true)


func reset_sequence() -> void:
	reset_memory()


func get_normalized_sequence_source_ids() -> Array[String]:
	return _normalized_memory_ids(sequence_source_ids)


func get_expected_sequence_source_id() -> String:
	var sequence: Array[String] = get_normalized_sequence_source_ids()
	if memory_active or sequence.is_empty() or sequence_index >= sequence.size():
		return ""
	return sequence[sequence_index]


func get_sequence_wrong_input_behavior_name() -> String:
	return SequenceWrongInputBehavior.keys()[sequence_wrong_input_behavior].to_lower()


func _any_configured_source_active(configured_ids: Array[String]) -> bool:
	for source_id: String in _normalized_memory_ids(configured_ids):
		if get_source_state(source_id):
			return true
	return false


func _normalized_memory_ids(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		var normalized: String = _normalize_memory_id(value)
		if normalized != "" and not result.has(normalized):
			result.append(normalized)
	return result


func _normalize_memory_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")


func get_operation_name() -> String:
	return Operation.keys()[operation].to_lower()


func reset_target() -> void:
	timer_remaining = 0.0
	counter_value = 0
	latched_active = initial_active if operation == Operation.LATCH else false
	memory_active = (
		initial_active
		if operation in [Operation.TOGGLE, Operation.SET_RESET, Operation.SEQUENCE]
		else false
	)
	sequence_index = (
		get_normalized_sequence_source_ids().size()
		if operation == Operation.SEQUENCE and memory_active
		else 0
	)
	sequence_history.clear()
	sequence_input_count = 0
	sequence_wrong_input_count = 0
	memory_transition_count = 0
	last_memory_event = "reset"
	rising_edge_count = 0
	set_process(false)
	super.reset_target()
	_evaluate_source_states()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["logic"] = get_operation_name()
	data["timer_remaining"] = snappedf(timer_remaining, 0.01)
	data["counter"] = counter_value
	data["counter_target"] = counter_target
	data["latched"] = latched_active
	data["memory_active"] = memory_active
	data["memory_transitions"] = memory_transition_count
	data["memory_event"] = last_memory_event
	data["set_source_ids"] = _normalized_memory_ids(set_source_ids)
	data["reset_source_ids"] = _normalized_memory_ids(reset_source_ids)
	data["sequence_index"] = sequence_index
	data["sequence_length"] = get_normalized_sequence_source_ids().size()
	data["sequence_history"] = sequence_history.duplicate()
	data["sequence_expected"] = get_expected_sequence_source_id()
	data["sequence_inputs"] = sequence_input_count
	data["sequence_wrong_inputs"] = sequence_wrong_input_count
	data["sequence_wrong_input_behavior"] = get_sequence_wrong_input_behavior_name()
	data["rising_edges"] = rising_edge_count
	return data
