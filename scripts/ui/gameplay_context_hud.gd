extends CanvasLayer
class_name GameplayContextHUD

const RecordedObjectCatalogScript = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)
const RecordedObjectSpellControllerScript = preload(
	"res://scripts/player/player_recorded_object_spell_controller.gd"
)

var player: Node3D
var panel: PanelContainer
var eyebrow_label: Label
var title_label: Label
var state_label: Label
var controls_label: Label
var refresh_remaining: float = 0.0
var transient_context: Dictionary = {}
var transient_expires_msec: int = 0


func _ready() -> void:
	layer = 36
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("gameplay_context_hud")
	add_to_group("debuggable")
	player = get_parent() as Node3D
	_build_ui()
	_ensure_recorded_object_spell_runtime()
	call_deferred("_bind_optional_sources")


func _process(delta: float) -> void:
	refresh_remaining = maxf(refresh_remaining - delta, 0.0)
	if refresh_remaining <= 0.0:
		refresh_remaining = 0.08
		_refresh()


func publish_context(
	source_id: String,
	data: Dictionary,
	duration_seconds: float = 2.5
) -> void:
	transient_context = data.duplicate(true)
	transient_context["source_id"] = source_id
	transient_expires_msec = (
		Time.get_ticks_msec()
		+ int(maxf(duration_seconds, 0.1) * 1000.0)
	)
	_refresh()


func clear_context(source_id: String = "") -> void:
	if (
		source_id == ""
		or str(transient_context.get("source_id", "")) == source_id
	):
		transient_context.clear()
		transient_expires_msec = 0
	_refresh()


func _ensure_recorded_object_spell_runtime() -> void:
	if player == null or not is_instance_valid(player):
		return
	var controller: Node = player.get_node_or_null(
		"RecordedObjectSpellController"
	)
	if controller == null:
		controller = RecordedObjectSpellControllerScript.new()
		controller.name = "RecordedObjectSpellController"
		player.add_child(controller)


func _bind_optional_sources() -> void:
	var summon_manager: Node = get_tree().get_first_node_in_group(
		"summon_managers"
	)
	if summon_manager == null:
		return
	_connect_source_signal(
		summon_manager,
		"summon_created",
		_on_familiar_summoned
	)
	_connect_source_signal(
		summon_manager,
		"summon_dismissed",
		_on_familiar_dismissed
	)
	_connect_source_signal(
		summon_manager,
		"summon_command_changed",
		_on_familiar_command_changed
	)


func _connect_source_signal(
	source: Node,
	signal_name: StringName,
	callback: Callable
) -> void:
	if (
		source.has_signal(signal_name)
		and not source.is_connected(signal_name, callback)
	):
		source.connect(signal_name, callback)


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "GameplayContextPanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -320.0
	panel.offset_top = -270.0
	panel.offset_right = 320.0
	panel.offset_bottom = -168.0
	panel.add_to_group("menu_suppressed_hud")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.026, 0.045, 0.95)
	style.border_color = Color(0.38, 0.82, 1.0, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 11)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)

	eyebrow_label = Label.new()
	eyebrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow_label.add_theme_font_size_override("font_size", 9)
	eyebrow_label.add_theme_color_override(
		"font_color",
		Color(0.46, 0.82, 1.0, 1.0)
	)
	stack.add_child(eyebrow_label)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.98, 1.0, 1.0)
	)
	stack.add_child(title_label)

	state_label = Label.new()
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", 11)
	stack.add_child(state_label)

	controls_label = Label.new()
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.add_theme_font_size_override("font_size", 9)
	controls_label.add_theme_color_override(
		"font_color",
		Color(0.63, 0.73, 0.84, 1.0)
	)
	stack.add_child(controls_label)
	panel.visible = false


func _refresh() -> void:
	if panel == null:
		return
	var object_context: Dictionary = _get_recorded_object_context()
	if not object_context.is_empty():
		_apply_context(object_context)
		return
	var soul_context: Dictionary = _get_soul_grip_context()
	if not soul_context.is_empty():
		_apply_context(soul_context)
		return
	if (
		not transient_context.is_empty()
		and Time.get_ticks_msec() <= transient_expires_msec
	):
		_apply_context(transient_context)
		return
	transient_context.clear()
	transient_expires_msec = 0
	panel.visible = false


func _get_recorded_object_context() -> Dictionary:
	var manager: Node = get_tree().get_first_node_in_group(
		"recorded_object_manager"
	)
	if manager == null or not bool(manager.get("placement_active")):
		return {}
	var selected_id: String = RecordedObjectCatalogScript.get_selected_blueprint_id()
	var definition: Dictionary = RecordedObjectCatalogScript.get_definition(
		selected_id
	)
	var debug: Dictionary = {}
	if manager.has_method("get_debug_data"):
		var value: Variant = manager.call("get_debug_data")
		if value is Dictionary:
			debug = value as Dictionary
	var valid: bool = bool(debug.get("placement_valid", false))
	var state: String = "VALID POSITION"
	if not valid:
		state = str(debug.get(
			"invalid_reason",
			"That reproduction cannot fit there."
		))
	return {
		"eyebrow": "REPRODUCE OBJECT",
		"title": (
			str(definition.get("icon", "▣"))
			+ "  "
			+ str(definition.get(
				"display_name",
				selected_id.capitalize()
			))
		),
		"state": (
			state
			+ "  •  DEPTH "
			+ str(snappedf(
				float(debug.get("placement_depth_offset", 0.0)),
				0.25
			))
			+ "  •  ROTATION "
			+ str(int(debug.get("yaw_degrees", 0.0)))
			+ "°"
		),
		"controls": "D-pad ↑/↓ move depth  •  L/R rotate  •  A place  •  B cancel",
		"valid": valid,
	}


func _get_soul_grip_context() -> Dictionary:
	var controller: Node = get_tree().get_first_node_in_group(
		"soul_grip_controllers"
	)
	if controller == null:
		return {}
	var channel_requested: bool = bool(controller.get("channel_requested"))
	var held_target: Variant = controller.get("held_target")
	if not channel_requested and held_target == null:
		return {}
	var title: String = "SEEKING SOUL-MARKED OBJECT"
	if held_target is Node:
		title = "HOLDING  " + str((held_target as Node).name)
	var distance: float = float(controller.get("hold_distance"))
	return {
		"eyebrow": "SOUL GRASP",
		"title": title,
		"state": "HOLD DISTANCE  " + str(snappedf(distance, 0.1)),
		"controls": "D-pad ↑/↓ move depth  •  L/R rotate  •  Right stick aim  •  Release Cast to drop",
		"valid": held_target != null,
	}


func _apply_context(data: Dictionary) -> void:
	panel.visible = true
	eyebrow_label.text = str(data.get("eyebrow", "CONTEXT"))
	title_label.text = str(data.get("title", ""))
	state_label.text = str(data.get("state", ""))
	state_label.add_theme_color_override(
		"font_color",
		Color(0.48, 1.0, 0.68, 1.0)
		if bool(data.get("valid", true))
		else Color(1.0, 0.48, 0.34, 1.0)
	)
	controls_label.text = str(data.get("controls", ""))


func _on_familiar_summoned(summon: Node) -> void:
	publish_context(
		"familiar",
		{
			"eyebrow": "FAMILIAR",
			"title": str(summon.get("display_name")) if summon != null else "Familiar summoned",
			"state": "PRESENCE ESTABLISHED",
			"controls": "Use the prepared familiar command to direct its behavior.",
			"valid": true,
		},
		3.0
	)


func _on_familiar_dismissed() -> void:
	publish_context(
		"familiar",
		{
			"eyebrow": "FAMILIAR",
			"title": "PRESENCE DISMISSED",
			"state": "The familiar blueprint remains prepared.",
			"controls": "Cast Summon Familiar again to call it back.",
			"valid": true,
		},
		2.0
	)


func _on_familiar_command_changed(command: String) -> void:
	publish_context(
		"familiar",
		{
			"eyebrow": "FAMILIAR COMMAND",
			"title": command.to_upper(),
			"state": "COMMAND UPDATED",
			"controls": "The active familiar will follow the new behavior order.",
			"valid": true,
		},
		2.5
	)


func get_debug_data() -> Dictionary:
	return {
		"visible": panel != null and panel.visible,
		"player_ready": player != null and is_instance_valid(player),
		"object_context": not _get_recorded_object_context().is_empty(),
		"soul_context": not _get_soul_grip_context().is_empty(),
		"transient_context": transient_context.duplicate(true),
	}
