extends CanvasLayer
class_name TacticalDecisionOverlay


@export var telemetry_toggle_key: Key = KEY_F2
@export var show_on_start: bool = true
@export_range(0.05, 1.0, 0.05) var refresh_interval: float = 0.15

var recorder: TacticalDecisionRecorder
var telemetry_visible: bool = false
var refresh_remaining: float = 0.0
var refresh_count: int = 0
var last_render_signature: String = ""

var root_panel: PanelContainer
var title_label: Label
var summary_label: Label
var decision_label: Label
var candidates_label: Label
var coordination_label: Label
var footer_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_telemetry_visible(show_on_start)
	add_to_group("tactical_decision_overlay")


func _process(delta: float) -> void:
	if not telemetry_visible:
		return
	refresh_remaining = maxf(refresh_remaining - maxf(delta, 0.0), 0.0)
	if refresh_remaining > 0.0:
		return
	refresh_remaining = maxf(refresh_interval, 0.05)
	refresh_from_recorder()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.physical_keycode as Key
	if key == KEY_NONE:
		key = key_event.keycode as Key
	if key == telemetry_toggle_key:
		set_telemetry_visible(not telemetry_visible)
		get_viewport().set_input_as_handled()
		return
	if not telemetry_visible or recorder == null:
		return
	if key in [KEY_COMMA, KEY_LEFT]:
		recorder.step_back()
		refresh_from_recorder(true)
		get_viewport().set_input_as_handled()
	elif key in [KEY_PERIOD, KEY_RIGHT]:
		recorder.step_forward()
		refresh_from_recorder(true)
		get_viewport().set_input_as_handled()


func bind_recorder(value: TacticalDecisionRecorder) -> void:
	recorder = value
	last_render_signature = ""
	refresh_from_recorder(true)


func set_telemetry_visible(value: bool) -> void:
	telemetry_visible = value
	if root_panel != null:
		root_panel.visible = value
	set_process(value)
	if value:
		refresh_remaining = 0.0
		refresh_from_recorder(true)


func refresh_from_recorder(force: bool = false) -> void:
	if root_panel == null:
		return
	var frame: Dictionary = recorder.get_current_frame() if recorder != null else {}
	var debug: Dictionary = recorder.get_debug_data() if recorder != null else {}
	var signature: String = JSON.stringify(
		{"frame": frame, "debug": debug},
		"",
		true
	).sha256_text()
	if not force and signature == last_render_signature:
		return
	last_render_signature = signature
	refresh_count += 1
	_render(frame, debug)


func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.name = "TacticalDecisionPanel"
	root_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root_panel.position = Vector2(-590.0, 18.0)
	root_panel.size = Vector2(570.0, 660.0)
	root_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.06, 0.94)
	panel_style.border_color = Color(0.25, 0.62, 0.92, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	root_panel.add_theme_stylebox_override("panel", panel_style)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	root_panel.add_child(stack)

	title_label = _make_label(22)
	title_label.text = "TACTICAL FLIGHT RECORDER"
	stack.add_child(title_label)

	summary_label = _make_label(14)
	stack.add_child(summary_label)

	decision_label = _make_label(18)
	decision_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(decision_label)

	var separator_a := HSeparator.new()
	stack.add_child(separator_a)

	candidates_label = _make_label(14)
	candidates_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	candidates_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(candidates_label)

	var separator_b := HSeparator.new()
	stack.add_child(separator_b)

	coordination_label = _make_label(14)
	coordination_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(coordination_label)

	footer_label = _make_label(12)
	footer_label.text = "F2 hide • ,/← previous • ./→ next"
	stack.add_child(footer_label)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	return label


func _render(frame: Dictionary, debug: Dictionary) -> void:
	if frame.is_empty():
		summary_label.text = "No decisions recorded"
		decision_label.text = "Advance a laboratory scenario or bind this overlay to a tactical actor."
		candidates_label.text = "CANDIDATES\n• waiting"
		coordination_label.text = "COORDINATION\n• waiting"
		return

	var sequence: int = int(frame.get("sequence", 0))
	var repeat_count: int = int(frame.get("repeat_count", 1))
	var frame_count: int = int(debug.get("frame_count", 0))
	var cursor_value: int = int(debug.get("cursor", -1)) + 1
	summary_label.text = (
		"Frame " + str(cursor_value) + "/" + str(frame_count)
		+ " • sequence " + str(sequence)
		+ (" • repeated x" + str(repeat_count) if repeat_count > 1 else "")
	)

	var decision: Dictionary = _dictionary(frame.get("decision", {}))
	var selected: Dictionary = _dictionary(decision.get("selected", {}))
	var selected_name: String = str(
		selected.get(
			"display_name",
			decision.get("selected_name", decision.get("selected_id", "None"))
		)
	)
	var selected_score: float = float(
		selected.get("total_score", decision.get("selected_score", 0.0))
	)
	var reason: String = str(
		selected.get("reason", decision.get("reason", "No tactical reason"))
	)
	decision_label.text = (
		str(frame.get("source_name", "Actor")) + " • " + str(frame.get("event", "decision"))
		+ "\nSELECTED: " + selected_name
		+ "\nSCORE: " + str(snappedf(selected_score, 0.01))
		+ "\nWHY: " + reason
	)

	var candidates: Array[Dictionary] = _dictionary_array(
		decision.get("candidates", decision.get("trace", []))
	)
	var candidate_lines: Array[String] = ["CANDIDATES"]
	for index: int in range(mini(candidates.size(), 6)):
		var row: Dictionary = candidates[index]
		var validity: String = "✓" if bool(row.get("valid", true)) else "×"
		var name_text: String = str(
			row.get("display_name", row.get("action_id", "Action"))
		)
		var score: float = float(
			row.get("total_score", row.get("selected_score", 0.0))
		)
		var row_reason: String = str(row.get("reason", ""))
		if row_reason == "":
			var penalties: Array[String] = _string_array(row.get("penalties", []))
			var reasons: Array[String] = _string_array(row.get("reasons", []))
			row_reason = penalties[0] if not penalties.is_empty() else (
				reasons[0] if not reasons.is_empty() else "No special read"
			)
		candidate_lines.append(
			validity + " " + name_text + "  " + str(snappedf(score, 0.01))
			+ "\n    " + row_reason
		)
	candidates_label.text = "\n".join(candidate_lines)

	var coordination: Dictionary = _dictionary(frame.get("coordination", {}))
	var coordination_lines: Array[String] = ["COORDINATION"]
	var squad_id: String = str(
		coordination.get("squad_id", decision.get("squad_id", "none"))
	)
	coordination_lines.append("Squad: " + squad_id)
	var blackboard: Dictionary = _dictionary(coordination.get("blackboard", coordination))
	coordination_lines.append(
		"Setup: " + _join_or_none(blackboard.get("claimed_setup_reactions", []))
	)
	coordination_lines.append(
		"Payoff: " + _join_or_none(blackboard.get("claimed_payoff_reactions", []))
	)
	coordination_lines.append(
		"Lanes: " + _join_or_none(blackboard.get("occupied_engagement_lanes", []))
	)
	coordination_lines.append(
		"Intents: " + _join_or_none(blackboard.get("squad_intent_tags", []))
	)
	coordination_label.text = "\n".join(coordination_lines)


func _join_or_none(value: Variant) -> String:
	var values: Array[String] = _string_array(value)
	return "none" if values.is_empty() else ", ".join(values)


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result


func get_debug_data() -> Dictionary:
	return {
		"telemetry_visible": telemetry_visible,
		"processing": is_processing(),
		"refresh_count": refresh_count,
		"has_recorder": recorder != null,
		"last_render_signature": last_render_signature,
	}
