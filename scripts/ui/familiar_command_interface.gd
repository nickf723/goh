extends CanvasLayer
class_name FamiliarCommandInterface

signal interface_visibility_changed(visible: bool)
signal command_menu_opened(commands: Array[String])
signal command_menu_closed(committed: bool)
signal targeting_changed(active: bool)
signal command_committed(command_id: String, result: Dictionary)

const MENU_ACTION: StringName = &"familiar_command_menu"
const CONFIRM_ACTION: StringName = &"familiar_command_confirm"
const CANCEL_ACTION: StringName = &"familiar_command_cancel"

const COMMAND_ORDER: Array[String] = [
	"follow",
	"assist",
	"focus",
	"move_to",
	"stay",
	"come_here",
]
const COMMAND_LABELS: Dictionary = {
	"follow": "Follow",
	"stay": "Stay Here",
	"come_here": "Come Here",
	"move_to": "Go There",
	"assist": "Assist",
	"focus": "Focus Target",
}
const COMMAND_DESCRIPTIONS: Dictionary = {
	"follow": "Travel beside Grace.",
	"stay": "Hold this position.",
	"come_here": "Return directly to Grace.",
	"move_to": "Move to an aimed world position.",
	"assist": "Choose and pressure nearby threats.",
	"focus": "Prioritize Grace's locked target.",
}

@export_group("Presentation")
@export_range(0.05, 1.0, 0.05) var radial_time_scale: float = 0.35
@export_range(0.1, 1.0, 0.05) var stick_deadzone: float = 0.38
@export_range(10.0, 160.0, 5.0) var targeting_distance: float = 80.0
@export var keyboard_menu_key: Key = KEY_F

var summon_manager: Node
var actor: Node3D
var action_state: PlayerActionState
var active_familiar: Node3D

var compact_panel: PanelContainer
var compact_label: Label
var radial_root: Control
var radial_panel: PanelContainer
var radial_title: Label
var radial_description: Label
var radial_button_layer: Control
var target_root: Control
var target_label: Label
var target_marker: Node3D

var available_commands: Array[String] = []
var command_buttons: Array[Button] = []
var selected_index: int = 0
var menu_open: bool = false
var targeting_active: bool = false
var target_valid: bool = false
var target_position: Vector3 = Vector3.ZERO
var active_device: int = 0
var previous_time_scale: float = 1.0
var previous_allow_movement: bool = true
var focus_was_open: bool = false
var cancelled_current_hold: bool = false
var menu_open_count: int = 0
var command_commit_count: int = 0
var targeting_confirm_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 72
	_ensure_input_actions()
	_build_interface()
	add_to_group("familiar_command_interface")
	add_to_group("debuggable")
	_refresh_visibility()


func bind(manager_value: Node, actor_value: Node3D) -> void:
	_disconnect_manager()
	summon_manager = manager_value
	actor = actor_value
	action_state = (
		actor.get_node_or_null("PlayerActionState") as PlayerActionState
		if actor != null
		else null
	)
	_connect_manager()
	active_familiar = _get_active_familiar()
	_refresh_visibility()


func _exit_tree() -> void:
	_disconnect_manager()
	_close_all_surfaces(false)
	_remove_target_marker()


func _process(_delta: float) -> void:
	if active_familiar != null and not is_instance_valid(active_familiar):
		active_familiar = null
		_refresh_visibility()
	if menu_open:
		_update_selection_from_stick()
	if targeting_active:
		_update_targeting_position()
	_update_compact_status()


func _input(event: InputEvent) -> void:
	if active_familiar == null or not is_instance_valid(active_familiar):
		return
	if event.is_action_pressed(MENU_ACTION):
		if handle_menu_button(true, event.device):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_released(MENU_ACTION):
		if handle_menu_button(false, event.device):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(CANCEL_ACTION):
		if cancel_interface("input_cancel"):
			get_viewport().set_input_as_handled()
		return
	if targeting_active and event.is_action_pressed(CONFIRM_ACTION):
		if confirm_current_target():
			get_viewport().set_input_as_handled()


func handle_menu_button(pressed: bool, device: int = 0) -> bool:
	if pressed:
		cancelled_current_hold = false
		return open_command_menu(device)
	if cancelled_current_hold:
		cancelled_current_hold = false
		return true
	if menu_open:
		return commit_selected_command()
	return false


func open_command_menu(device: int = 0) -> bool:
	if targeting_active or menu_open:
		return false
	active_familiar = _get_active_familiar()
	if active_familiar == null:
		return false
	if action_state != null and action_state.is_focus_menu_open:
		return false
	available_commands = _resolve_available_commands()
	if available_commands.is_empty():
		_show_message("This familiar has no available commands.")
		return false
	active_device = device
	selected_index = _get_current_command_index()
	_rebuild_command_buttons()
	menu_open = true
	menu_open_count += 1
	previous_time_scale = Engine.time_scale
	Engine.time_scale = minf(previous_time_scale, radial_time_scale)
	if action_state != null:
		focus_was_open = action_state.is_focus_menu_open
		previous_allow_movement = action_state.allow_movement_during_focus_menu
		action_state.allow_movement_during_focus_menu = false
		action_state.set_focus_menu_open(true)
	radial_root.visible = true
	_refresh_command_highlight()
	command_menu_opened.emit(available_commands.duplicate())
	return true


func close_command_menu(committed: bool = false) -> bool:
	if not menu_open:
		return false
	menu_open = false
	radial_root.visible = false
	_restore_menu_state()
	command_menu_closed.emit(committed)
	return true


func cancel_interface(reason: String = "cancelled") -> bool:
	var handled: bool = false
	if menu_open:
		cancelled_current_hold = true
		handled = close_command_menu(false) or handled
	if targeting_active:
		handled = cancel_targeting(reason) or handled
	return handled


func select_command_by_id(command_id: String) -> bool:
	var normalized: String = _normalize_command(command_id)
	var found_index: int = available_commands.find(normalized)
	if found_index < 0:
		return false
	selected_index = found_index
	_refresh_command_highlight()
	return true


func select_command_index(index: int) -> bool:
	if available_commands.is_empty():
		return false
	selected_index = clampi(index, 0, available_commands.size() - 1)
	_refresh_command_highlight()
	return true


func commit_selected_command() -> bool:
	if not menu_open or available_commands.is_empty():
		return false
	var command_id: String = available_commands[selected_index]
	close_command_menu(true)
	if command_id == "move_to":
		return begin_move_targeting()
	var result: Dictionary = _issue_command(command_id)
	command_commit_count += 1
	command_committed.emit(command_id, result)
	return bool(result.get("ok", false))


func begin_move_targeting() -> bool:
	if active_familiar == null or not is_instance_valid(active_familiar):
		return false
	targeting_active = true
	target_valid = false
	if action_state != null:
		focus_was_open = action_state.is_focus_menu_open
		previous_allow_movement = action_state.allow_movement_during_focus_menu
		action_state.allow_movement_during_focus_menu = false
		action_state.set_focus_menu_open(true)
	target_root.visible = true
	_ensure_target_marker()
	targeting_changed.emit(true)
	return true


func confirm_current_target() -> bool:
	if not targeting_active or not target_valid:
		return false
	return confirm_move_to_target(target_position)


func confirm_move_to_target(world_position: Vector3) -> bool:
	if not targeting_active:
		return false
	var result: Dictionary = _issue_command("move_to", world_position)
	if not bool(result.get("ok", false)):
		_show_message(str(result.get("error", "The familiar cannot reach that command.")))
		return false
	targeting_confirm_count += 1
	command_commit_count += 1
	command_committed.emit("move_to", result)
	_finish_targeting()
	return true


func cancel_targeting(_reason: String = "cancelled") -> bool:
	if not targeting_active:
		return false
	_finish_targeting()
	return true


func is_interface_visible() -> bool:
	return compact_panel != null and compact_panel.visible


func is_menu_open() -> bool:
	return menu_open


func is_targeting() -> bool:
	return targeting_active


func get_selected_command_id() -> String:
	if available_commands.is_empty():
		return ""
	return available_commands[clampi(selected_index, 0, available_commands.size() - 1)]


func get_available_commands() -> Array[String]:
	return available_commands.duplicate()


func _connect_manager() -> void:
	if summon_manager == null:
		return
	if summon_manager.has_signal("summon_created") and not summon_manager.is_connected(
		"summon_created",
		Callable(self, "_on_summon_created")
	):
		summon_manager.connect("summon_created", Callable(self, "_on_summon_created"))
	if summon_manager.has_signal("summon_dismissed") and not summon_manager.is_connected(
		"summon_dismissed",
		Callable(self, "_on_summon_dismissed")
	):
		summon_manager.connect("summon_dismissed", Callable(self, "_on_summon_dismissed"))
	if summon_manager.has_signal("summon_command_changed") and not summon_manager.is_connected(
		"summon_command_changed",
		Callable(self, "_on_command_changed")
	):
		summon_manager.connect("summon_command_changed", Callable(self, "_on_command_changed"))


func _disconnect_manager() -> void:
	if summon_manager == null:
		return
	for signal_name: String in ["summon_created", "summon_dismissed", "summon_command_changed"]:
		var callback_name: String = {
			"summon_created": "_on_summon_created",
			"summon_dismissed": "_on_summon_dismissed",
			"summon_command_changed": "_on_command_changed",
		}.get(signal_name, "")
		var callback: Callable = Callable(self, callback_name)
		if callback_name != "" and summon_manager.has_signal(signal_name) and summon_manager.is_connected(signal_name, callback):
			summon_manager.disconnect(signal_name, callback)


func _on_summon_created(summon: Node3D) -> void:
	active_familiar = summon
	_refresh_visibility()


func _on_summon_dismissed() -> void:
	active_familiar = null
	_close_all_surfaces(false)
	_refresh_visibility()


func _on_command_changed(_command: String) -> void:
	_update_compact_status()


func _refresh_visibility() -> void:
	var should_show: bool = active_familiar != null and is_instance_valid(active_familiar)
	if compact_panel != null:
		compact_panel.visible = should_show
	if not should_show:
		_close_all_surfaces(false)
	interface_visibility_changed.emit(should_show)


func _close_all_surfaces(committed: bool) -> void:
	if menu_open:
		close_command_menu(committed)
	if targeting_active:
		_finish_targeting()


func _restore_menu_state() -> void:
	Engine.time_scale = previous_time_scale
	if action_state != null:
		action_state.allow_movement_during_focus_menu = previous_allow_movement
		action_state.set_focus_menu_open(focus_was_open)


func _finish_targeting() -> void:
	targeting_active = false
	target_valid = false
	target_root.visible = false
	if target_marker != null:
		target_marker.visible = false
	if action_state != null:
		action_state.allow_movement_during_focus_menu = previous_allow_movement
		action_state.set_focus_menu_open(focus_was_open)
	targeting_changed.emit(false)


func _resolve_available_commands() -> Array[String]:
	var resolved: Array[String] = []
	if summon_manager != null and summon_manager.has_method("get_available_familiar_commands"):
		var value: Variant = summon_manager.call("get_available_familiar_commands")
		if value is Array:
			for raw: Variant in value as Array:
				var command_id: String = _normalize_command(str(raw))
				if COMMAND_LABELS.has(command_id) and not resolved.has(command_id):
					resolved.append(command_id)
	var ordered: Array[String] = []
	for command_id: String in COMMAND_ORDER:
		if resolved.has(command_id):
			ordered.append(command_id)
	for command_id: String in resolved:
		if not ordered.has(command_id):
			ordered.append(command_id)
	return ordered


func _get_current_command_index() -> int:
	var state: Dictionary = _get_command_state()
	var current: String = _normalize_command(str(state.get("command_id", state.get("command", "follow"))))
	var index: int = available_commands.find(current)
	return index if index >= 0 else 0


func _issue_command(command_id: String, destination: Vector3 = Vector3.INF) -> Dictionary:
	if summon_manager == null or not summon_manager.has_method("issue_familiar_command"):
		return {"ok": false, "error": "summon manager unavailable"}
	var result_value: Variant = summon_manager.call(
		"issue_familiar_command",
		command_id,
		destination
	)
	var result: Dictionary = result_value as Dictionary if result_value is Dictionary else {"ok": bool(result_value)}
	if bool(result.get("ok", false)):
		_show_message(
			_get_familiar_name()
			+ " command: "
			+ str(COMMAND_LABELS.get(_normalize_command(command_id), command_id.capitalize()))
		)
	return result


func _get_command_state() -> Dictionary:
	if summon_manager != null and summon_manager.has_method("get_familiar_command_state"):
		var value: Variant = summon_manager.call("get_familiar_command_state")
		return value as Dictionary if value is Dictionary else {}
	return {}


func _get_active_familiar() -> Node3D:
	if summon_manager != null and summon_manager.has_method("get_active_summon"):
		var value: Variant = summon_manager.call("get_active_summon")
		return value as Node3D if value is Node3D and is_instance_valid(value) else null
	return null


func _get_familiar_name() -> String:
	if summon_manager != null and summon_manager.has_method("get_active_familiar_display_name"):
		return str(summon_manager.call("get_active_familiar_display_name"))
	return "Familiar"


func _update_selection_from_stick() -> void:
	var vector: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)
	if vector.length() < stick_deadzone or available_commands.is_empty():
		return
	var normalized: Vector2 = vector.normalized()
	var best_index: int = selected_index
	var best_dot: float = -INF
	for index: int in range(available_commands.size()):
		var direction: Vector2 = _command_direction(index, available_commands.size())
		var score: float = normalized.dot(direction)
		if score > best_dot:
			best_dot = score
			best_index = index
	if best_index != selected_index:
		selected_index = best_index
		_refresh_command_highlight()


func _command_direction(index: int, count: int) -> Vector2:
	var angle: float = -PI * 0.5 + TAU * float(index) / float(maxi(count, 1))
	return Vector2(cos(angle), sin(angle))


func _rebuild_command_buttons() -> void:
	for button: Button in command_buttons:
		if is_instance_valid(button):
			button.queue_free()
	command_buttons.clear()
	var count: int = available_commands.size()
	for index: int in range(count):
		var command_id: String = available_commands[index]
		var button := Button.new()
		button.name = "Command_" + command_id
		button.text = str(COMMAND_LABELS.get(command_id, command_id.capitalize()))
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(132.0, 48.0)
		button.size = Vector2(132.0, 48.0)
		var direction: Vector2 = _command_direction(index, count)
		button.position = Vector2(246.0, 188.0) + direction * 145.0 - button.size * 0.5
		button.mouse_entered.connect(func() -> void:
			select_command_index(index)
		)
		button.pressed.connect(func() -> void:
			select_command_index(index)
			commit_selected_command()
		)
		radial_button_layer.add_child(button)
		command_buttons.append(button)


func _refresh_command_highlight() -> void:
	if available_commands.is_empty():
		return
	selected_index = clampi(selected_index, 0, available_commands.size() - 1)
	for index: int in range(command_buttons.size()):
		var button: Button = command_buttons[index]
		button.modulate = Color(1.0, 0.84, 0.38) if index == selected_index else Color(0.76, 0.86, 0.96)
	var command_id: String = available_commands[selected_index]
	radial_title.text = str(COMMAND_LABELS.get(command_id, command_id.capitalize()))
	radial_description.text = str(COMMAND_DESCRIPTIONS.get(command_id, "Issue familiar command."))


func _update_compact_status() -> void:
	if compact_label == null or active_familiar == null or not is_instance_valid(active_familiar):
		return
	var state: Dictionary = _get_command_state()
	var command_id: String = _normalize_command(str(state.get("command_id", state.get("command", "follow"))))
	var command_label: String = str(COMMAND_LABELS.get(command_id, command_id.capitalize()))
	var suspended: bool = bool(state.get("suspended", false))
	var suffix: String = ""
	if suspended:
		suffix = "  •  SUSPENDED: " + str(state.get("suspend_reason", "unsafe")).replace("_", " ").to_upper()
	compact_label.text = (
		_get_familiar_name()
		+ "\n"
		+ command_label
		+ suffix
		+ "\nHold L3 / F for commands"
	)


func _update_targeting_position() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		target_valid = false
		return
	var screen_center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var origin: Vector3 = camera.project_ray_origin(screen_center)
	var direction: Vector3 = camera.project_ray_normal(screen_center)
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * targeting_distance,
		1
	)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.has("position"):
		target_position = result.get("position", Vector3.ZERO) as Vector3
		target_valid = true
	else:
		var plane := Plane(Vector3.UP, 0.0)
		var intersection: Variant = plane.intersects_ray(origin, direction)
		if intersection is Vector3:
			target_position = intersection as Vector3
			target_valid = origin.distance_to(target_position) <= targeting_distance
		else:
			target_valid = false
	_ensure_target_marker()
	if target_marker != null:
		target_marker.visible = target_valid
		if target_valid:
			target_marker.global_position = target_position + Vector3.UP * 0.06
	target_label.text = (
		"GO THERE\nA / Enter: confirm   B / Esc: cancel"
		if target_valid
		else "Aim at reachable ground"
	)


func _ensure_target_marker() -> void:
	if target_marker != null and is_instance_valid(target_marker):
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	target_marker = Node3D.new()
	target_marker.name = "FamiliarCommandTargetMarker"
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.72
	mesh.bottom_radius = 0.72
	mesh.height = 0.06
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.18, 0.92, 1.0, 0.54)
	material.emission_enabled = true
	material.emission = Color(0.12, 0.74, 1.0)
	material.emission_energy_multiplier = 2.2
	ring.material_override = material
	target_marker.add_child(ring)
	var label := Label3D.new()
	label.text = "GO THERE"
	label.position.y = 0.75
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22
	label.pixel_size = 0.006
	label.outline_size = 7
	label.modulate = Color(0.4, 0.96, 1.0)
	target_marker.add_child(label)
	target_marker.visible = false
	scene_root.add_child(target_marker)


func _remove_target_marker() -> void:
	if target_marker != null and is_instance_valid(target_marker):
		target_marker.queue_free()
	target_marker = null


func _build_interface() -> void:
	compact_panel = PanelContainer.new()
	compact_panel.name = "FamiliarCommandStatus"
	compact_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	compact_panel.position = Vector2(-340.0, -126.0)
	compact_panel.size = Vector2(320.0, 106.0)
	compact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var compact_style := StyleBoxFlat.new()
	compact_style.bg_color = Color(0.02, 0.045, 0.075, 0.9)
	compact_style.border_color = Color(0.2, 0.82, 0.92, 0.82)
	compact_style.set_border_width_all(2)
	compact_style.set_corner_radius_all(9)
	compact_style.set_content_margin_all(12.0)
	compact_panel.add_theme_stylebox_override("panel", compact_style)
	compact_label = Label.new()
	compact_label.add_theme_font_size_override("font_size", 14)
	compact_label.add_theme_color_override("font_color", Color(0.78, 0.96, 1.0))
	compact_panel.add_child(compact_label)
	add_child(compact_panel)

	radial_root = Control.new()
	radial_root.name = "FamiliarCommandRadial"
	radial_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radial_root.mouse_filter = Control.MOUSE_FILTER_STOP
	radial_root.visible = false
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.005, 0.012, 0.025, 0.62)
	radial_root.add_child(dim)
	radial_panel = PanelContainer.new()
	radial_panel.set_anchors_preset(Control.PRESET_CENTER)
	radial_panel.position = Vector2(-260.0, -225.0)
	radial_panel.size = Vector2(520.0, 450.0)
	var radial_style := StyleBoxFlat.new()
	radial_style.bg_color = Color(0.02, 0.04, 0.068, 0.95)
	radial_style.border_color = Color(0.28, 0.86, 0.96, 0.9)
	radial_style.set_border_width_all(2)
	radial_style.set_corner_radius_all(18)
	radial_panel.add_theme_stylebox_override("panel", radial_style)
	radial_root.add_child(radial_panel)
	var surface := Control.new()
	surface.custom_minimum_size = Vector2(520.0, 450.0)
	radial_panel.add_child(surface)
	radial_button_layer = Control.new()
	radial_button_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(radial_button_layer)
	radial_title = Label.new()
	radial_title.position = Vector2(160.0, 176.0)
	radial_title.size = Vector2(200.0, 34.0)
	radial_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radial_title.add_theme_font_size_override("font_size", 24)
	radial_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42))
	surface.add_child(radial_title)
	radial_description = Label.new()
	radial_description.position = Vector2(125.0, 212.0)
	radial_description.size = Vector2(270.0, 54.0)
	radial_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radial_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radial_description.add_theme_font_size_override("font_size", 14)
	radial_description.add_theme_color_override("font_color", Color(0.72, 0.86, 0.94))
	surface.add_child(radial_description)
	var instruction := Label.new()
	instruction.position = Vector2(90.0, 404.0)
	instruction.size = Vector2(340.0, 30.0)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.text = "Right stick selects • Release L3 / F to command • B / Esc cancels"
	instruction.add_theme_font_size_override("font_size", 12)
	instruction.add_theme_color_override("font_color", Color(0.58, 0.72, 0.82))
	surface.add_child(instruction)
	add_child(radial_root)

	target_root = Control.new()
	target_root.name = "FamiliarCommandTargeting"
	target_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_root.visible = false
	target_label = Label.new()
	target_label.set_anchors_preset(Control.PRESET_CENTER)
	target_label.position = Vector2(-210.0, 76.0)
	target_label.size = Vector2(420.0, 64.0)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.add_theme_font_size_override("font_size", 18)
	target_label.add_theme_color_override("font_color", Color(0.48, 0.96, 1.0))
	target_root.add_child(target_label)
	var reticle := Label.new()
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-18.0, -25.0)
	reticle.size = Vector2(36.0, 50.0)
	reticle.text = "+"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size", 34)
	reticle.add_theme_color_override("font_color", Color(0.54, 0.98, 1.0))
	target_root.add_child(reticle)
	add_child(target_root)


func _ensure_input_actions() -> void:
	_ensure_action(MENU_ACTION)
	_ensure_action(CONFIRM_ACTION)
	_ensure_action(CANCEL_ACTION)
	_ensure_key(MENU_ACTION, keyboard_menu_key)
	_ensure_joy_button(MENU_ACTION, JOY_BUTTON_LEFT_STICK)
	_ensure_key(CONFIRM_ACTION, KEY_ENTER)
	_ensure_mouse_button(CONFIRM_ACTION, MOUSE_BUTTON_LEFT)
	_ensure_joy_button(CONFIRM_ACTION, JOY_BUTTON_A)
	_ensure_key(CANCEL_ACTION, KEY_ESCAPE)
	_ensure_mouse_button(CANCEL_ACTION, MOUSE_BUTTON_RIGHT)
	_ensure_joy_button(CANCEL_ACTION, JOY_BUTTON_B)


func _ensure_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func _ensure_key(action_name: StringName, keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode == keycode or key_event.keycode == keycode:
				return
	var input := InputEventKey.new()
	input.physical_keycode = keycode
	InputMap.action_add_event(action_name, input)


func _ensure_mouse_button(action_name: StringName, button_index: MouseButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button_index:
			return
	var input := InputEventMouseButton.new()
	input.button_index = button_index
	InputMap.action_add_event(action_name, input)


func _ensure_joy_button(action_name: StringName, button_index: int) -> void:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return
	var input := InputEventJoypadButton.new()
	input.button_index = button_index
	InputMap.action_add_event(action_name, input)


func _normalize_command(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"visible": is_interface_visible(),
		"menu_open": menu_open,
		"targeting": targeting_active,
		"target_valid": target_valid,
		"target_position": target_position,
		"available_commands": available_commands.duplicate(),
		"selected_command": get_selected_command_id(),
		"active_familiar": _get_familiar_name() if active_familiar != null else "none",
		"menu_action": str(MENU_ACTION),
		"confirm_action": str(CONFIRM_ACTION),
		"cancel_action": str(CANCEL_ACTION),
		"controller_menu_button": "L3",
		"controller_confirm_button": "A",
		"controller_cancel_button": "B",
		"menu_open_count": menu_open_count,
		"command_commit_count": command_commit_count,
		"targeting_confirm_count": targeting_confirm_count,
	}
