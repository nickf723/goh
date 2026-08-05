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
}

@export_group("Logic")
@export var operation: Operation = Operation.AND
@export_range(0.05, 30.0, 0.05) var timer_seconds: float = 4.0
@export_range(1, 99, 1) var counter_target: int = 3
@export var counter_wraps: bool = false
@export var latch_resets_when_all_sources_inactive: bool = false

var timer_remaining: float = 0.0
var counter_value: int = 0
var latched_active: bool = false
var rising_edge_count: int = 0


func _ready() -> void:
	evaluate_sources_as_or = false
	super._ready()
	set_process(operation == Operation.TIMER)


func _process(delta: float) -> void:
	if operation != Operation.TIMER or timer_remaining <= 0.0:
		return
	timer_remaining = maxf(timer_remaining - delta, 0.0)
	if timer_remaining <= 0.0:
		set_mechanism_active(false, {
			"reason": "timer_expired",
			"duration": timer_seconds,
		})


func _on_sources_ready() -> void:
	if operation == Operation.LATCH:
		latched_active = active
	elif operation == Operation.COUNTER and active:
		counter_value = counter_target


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
	set_mechanism_active(next_active, {
		"reason": "logic_evaluation",
		"operation": get_operation_name(),
		"active_sources": active_count,
		"source_count": source_count,
		"counter": counter_value,
		"counter_target": counter_target,
		"timer_remaining": timer_remaining,
	})


func trigger_timer(packet: Dictionary = {}) -> void:
	timer_remaining = maxf(timer_seconds, 0.05)
	var timer_packet: Dictionary = packet.duplicate(true)
	timer_packet["reason"] = "timer_triggered"
	timer_packet["duration"] = timer_remaining
	set_mechanism_active(true, timer_packet, true)
	set_process(true)


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


func get_operation_name() -> String:
	return Operation.keys()[operation].to_lower()


func reset_target() -> void:
	timer_remaining = 0.0
	counter_value = 0
	latched_active = initial_active if operation == Operation.LATCH else false
	set_process(operation == Operation.TIMER)
	super.reset_target()
	_evaluate_source_states()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["logic"] = get_operation_name()
	data["timer_remaining"] = snappedf(timer_remaining, 0.01)
	data["counter"] = counter_value
	data["counter_target"] = counter_target
	data["latched"] = latched_active
	data["rising_edges"] = rising_edge_count
	return data
