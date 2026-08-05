extends "res://scripts/levels/mechanism_network_lab_complete.gd"
class_name MechanismNetworkLabPerformance

@export_range(0.1, 1.0, 0.05) var active_timer_refresh_seconds: float = 0.25
@export_range(8.0, 120.0, 1.0) var instruction_label_visibility_distance: float = 42.0
@export_range(8.0, 120.0, 1.0) var network_readout_visibility_distance: float = 30.0

var timer_refresh_remaining: float = 0.0
var logic_text_cache: Dictionary = {}
var logic_color_cache: Dictionary = {}
var readout_text_cache: String = ""
var presentation_write_count: int = 0
var presentation_skip_count: int = 0
var timer_process_wake_count: int = 0


func _ready() -> void:
	super._ready()
	add_to_group("performance_budgeted_labs")
	_bind_logic_presentation_signals()
	_configure_label_visibility_budget(self)
	_refresh_all_presentations()
	_refresh_timer_processing()


func _process(delta: float) -> void:
	if not _has_active_timer():
		set_process(false)
		return
	timer_refresh_remaining -= maxf(delta, 0.0)
	if timer_refresh_remaining > 0.0:
		return
	timer_refresh_remaining = maxf(active_timer_refresh_seconds, 0.1)
	for logic: MechanismLogicNode in logic_nodes:
		if (
			logic != null
			and is_instance_valid(logic)
			and logic.operation == MechanismLogicNode.Operation.TIMER
			and logic.timer_remaining > 0.0
		):
			_refresh_logic_presentation(logic)
	_refresh_network_readout()


func _refresh_all_presentations() -> void:
	for logic: MechanismLogicNode in logic_nodes:
		if logic != null and is_instance_valid(logic):
			_refresh_logic_presentation(logic)
	_refresh_network_readout()
	_refresh_timer_processing()


func _bind_logic_presentation_signals() -> void:
	for logic: MechanismLogicNode in logic_nodes:
		if logic == null or not is_instance_valid(logic):
			continue
		var callback := Callable(self, "_on_logic_signal_changed").bind(logic)
		if not logic.mechanism_signal_changed.is_connected(callback):
			logic.mechanism_signal_changed.connect(callback)


func _on_logic_signal_changed(
	_mechanism_id: String,
	_active: bool,
	_packet: Dictionary,
	logic: MechanismLogicNode
) -> void:
	_refresh_logic_presentation(logic)
	_refresh_network_readout()
	_refresh_timer_processing()


func _refresh_logic_presentation(logic: MechanismLogicNode) -> void:
	if logic == null or not is_instance_valid(logic):
		return
	var label: Label3D = logic_labels.get(logic.get_instance_id()) as Label3D
	if label == null or not is_instance_valid(label):
		return
	var detail: String
	match logic.operation:
		MechanismLogicNode.Operation.COUNTER:
			detail = str(logic.counter_value) + "/" + str(logic.counter_target)
		MechanismLogicNode.Operation.TIMER:
			detail = str(snappedf(logic.timer_remaining, 0.1)) + "s"
		MechanismLogicNode.Operation.TOGGLE:
			detail = "stored " + ("1" if logic.memory_active else "0")
		MechanismLogicNode.Operation.SET_RESET:
			detail = "stored " + ("1" if logic.memory_active else "0")
		MechanismLogicNode.Operation.SEQUENCE:
			var sequence_length: int = logic.get_normalized_sequence_source_ids().size()
			detail = str(logic.sequence_index) + "/" + str(sequence_length)
			var expected_source_id: String = logic.get_expected_sequence_source_id()
			if expected_source_id != "":
				detail += " • next " + expected_source_id.to_upper()
		_:
			detail = str(logic.get_active_source_count()) + "/" + str(logic.get_bound_source_count())
	var next_text: String = (
		logic.display_name + "\n" + detail + " → " + ("ON" if logic.active else "OFF")
	)
	var next_color: Color = (
		Color(0.35, 1.0, 0.55)
		if logic.active
		else Color(1.0, 0.65, 0.25)
	)
	var key: int = logic.get_instance_id()
	if str(logic_text_cache.get(key, "")) != next_text:
		logic_text_cache[key] = next_text
		label.text = next_text
		presentation_write_count += 1
	else:
		presentation_skip_count += 1
	var cached_color: Variant = logic_color_cache.get(key)
	if not (cached_color is Color) or cached_color != next_color:
		logic_color_cache[key] = next_color
		label.modulate = next_color
		presentation_write_count += 1
	else:
		presentation_skip_count += 1


func _refresh_network_readout() -> void:
	if debug_readout == null or not is_instance_valid(debug_readout):
		return
	var active_logic: int = 0
	for logic: MechanismLogicNode in logic_nodes:
		if logic != null and is_instance_valid(logic) and logic.active:
			active_logic += 1
	var next_text: String = (
		"PUZZLE SIGNAL NETWORK\n"
		+ "Inputs " + str(input_nodes.size() - 1)
		+ "   Logic " + str(active_logic) + "/" + str(logic_nodes.size())
		+ "   Outputs " + str(output_nodes.size())
		+ "\nBoolean • timing • memory • ordered sequences • F8 resets lab"
	)
	if readout_text_cache == next_text:
		presentation_skip_count += 1
		return
	readout_text_cache = next_text
	debug_readout.text = next_text
	presentation_write_count += 1


func _refresh_timer_processing() -> void:
	var should_process: bool = _has_active_timer()
	if should_process and not is_processing():
		timer_process_wake_count += 1
		timer_refresh_remaining = 0.0
	set_process(should_process)


func _has_active_timer() -> bool:
	for logic: MechanismLogicNode in logic_nodes:
		if (
			logic != null
			and is_instance_valid(logic)
			and logic.operation == MechanismLogicNode.Operation.TIMER
			and logic.timer_remaining > 0.0
		):
			return true
	return false


func _configure_label_visibility_budget(node: Node) -> void:
	if node == null:
		return
	if node is Label3D:
		var label := node as Label3D
		label.visibility_range_end = (
			network_readout_visibility_distance
			if label == debug_readout
			else instruction_label_visibility_distance
		)
		label.visibility_range_end_margin = 4.0
	for child: Node in node.get_children():
		_configure_label_visibility_budget(child)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["performance_budgeted"] = true
	data["presentation_writes"] = presentation_write_count
	data["presentation_skips"] = presentation_skip_count
	data["timer_processing"] = is_processing()
	data["timer_process_wakes"] = timer_process_wake_count
	data["label_visibility_distance"] = instruction_label_visibility_distance
	return data
