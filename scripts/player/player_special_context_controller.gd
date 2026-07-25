extends Node
class_name PlayerSpecialContextController

signal context_opened(context: String)
signal context_closed
signal context_action_performed(context: String, action: String)

@export var context_action: String = "special_context"
@export var hold_seconds: float = 0.34
@export var animal_range: float = 4.0

var actor: CharacterBody3D
var summon_manager: PlayerSummonManager
var riding_controller: PlayerRidingController
var held: bool = false
var hold_time: float = 0.0
var wheel_open: bool = false
var context_name: String = "NONE"
var layer: CanvasLayer
var panel: PanelContainer
var title_label: Label
var option_label: Label


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		summon_manager = actor.get_node_or_null("SummonManager") as PlayerSummonManager
		riding_controller = actor.get_node_or_null("RidingController") as PlayerRidingController
	_ensure_input()
	_build_context_ui()
	add_to_group("debuggable")


func _process(delta: float) -> void:
	if held and not wheel_open:
		hold_time += delta
		if hold_time >= hold_seconds:
			_open_context()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(context_action):
		held = true
		hold_time = 0.0
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released(context_action):
		if wheel_open:
			_close_context()
		else:
			_perform_primary_action()
		held = false
		hold_time = 0.0
		get_viewport().set_input_as_handled()
		return
	if not wheel_open or not event.is_pressed():
		return
	if event is InputEventJoypadButton:
		var button: JoyButton = (event as InputEventJoypadButton).button_index
		if button == JOY_BUTTON_DPAD_LEFT:
			_perform_wheel_action(0)
		elif button == JOY_BUTTON_DPAD_UP:
			_perform_wheel_action(1)
		elif button == JOY_BUTTON_DPAD_RIGHT:
			_perform_wheel_action(2)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key: Key = (event as InputEventKey).physical_keycode
		if key == KEY_LEFT or key == KEY_1:
			_perform_wheel_action(0)
		elif key == KEY_UP or key == KEY_2:
			_perform_wheel_action(1)
		elif key == KEY_RIGHT or key == KEY_3:
			_perform_wheel_action(2)
		else:
			return
		get_viewport().set_input_as_handled()


func _perform_primary_action() -> void:
	if riding_controller != null and riding_controller.is_riding():
		riding_controller.dismount()
		_emit_action("MOUNT", "dismount")
		return
	var animal: ResearchableGoose = _nearest_goose()
	if animal != null:
		animal.perform_study_action("observe", actor)
		_emit_action("ANIMAL STUDY", "observe")
		return
	if summon_manager != null and summon_manager.get_active_summon() != null:
		var familiar: SpectralFamiliar = summon_manager.get_active_summon()
		var command: String = familiar.cycle_command()
		_show_message(familiar.display_name + ": " + command.capitalize())
		_emit_action("FAMILIAR", command)
		return
	if riding_controller != null:
		var mount: RideableMount = riding_controller.find_nearest_mount()
		if mount != null and riding_controller.mount_mount(mount):
			_emit_action("MOUNT", "mount")


func _open_context() -> void:
	wheel_open = true
	context_name = _resolve_context_name()
	_update_context_ui()
	if panel != null:
		panel.visible = true
	context_opened.emit(context_name)


func _close_context() -> void:
	wheel_open = false
	if panel != null:
		panel.visible = false
	context_closed.emit()


func _perform_wheel_action(index: int) -> void:
	match context_name:
		"FAMILIAR":
			if summon_manager == null or summon_manager.get_active_summon() == null:
				return
			var familiar: SpectralFamiliar = summon_manager.get_active_summon()
			if index == 0:
				familiar.set_command(SpectralFamiliar.COMMAND_FOLLOW)
			elif index == 1:
				familiar.set_command(SpectralFamiliar.COMMAND_STAY)
			else:
				familiar.set_command(SpectralFamiliar.COMMAND_ASSIST)
			_emit_action(context_name, familiar.command)
		"MOUNT":
			if riding_controller == null:
				return
			if index == 0 and riding_controller.is_riding():
				riding_controller.dismount()
				_emit_action(context_name, "dismount")
			elif index == 1 and not riding_controller.is_riding():
				riding_controller.call_mount()
				_emit_action(context_name, "call")
			elif index == 2 and not riding_controller.is_riding():
				riding_controller.dismiss_mount()
				_emit_action(context_name, "dismiss")
		"ANIMAL STUDY":
			var goose: ResearchableGoose = _nearest_goose()
			if goose == null:
				return
			var actions: Array[String] = ["observe", "feed", "soothe"]
			goose.perform_study_action(actions[index], actor)
			_emit_action(context_name, actions[index])
	_close_context()


func _resolve_context_name() -> String:
	if riding_controller != null and (riding_controller.is_riding() or riding_controller.find_nearest_mount() != null):
		return "MOUNT"
	if _nearest_goose() != null:
		return "ANIMAL STUDY"
	if summon_manager != null and summon_manager.get_active_summon() != null:
		return "FAMILIAR"
	return "NONE"


func _nearest_goose() -> ResearchableGoose:
	if actor == null:
		return null
	var best: ResearchableGoose
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group("study_animals"):
		var goose := node as ResearchableGoose
		if goose == null:
			continue
		var distance: float = actor.global_position.distance_to(goose.global_position)
		if distance <= animal_range and distance < best_distance:
			best = goose
			best_distance = distance
	return best


func _emit_action(context: String, action: String) -> void:
	context_action_performed.emit(context, action)
	_show_message(context.capitalize() + ": " + action.capitalize())


func _ensure_input() -> void:
	if not InputMap.has_action(context_action):
		InputMap.add_action(context_action, 0.2)
	_ensure_key(KEY_TAB)
	_ensure_joy_button(JOY_BUTTON_DPAD_DOWN)


func _ensure_key(keycode: Key) -> void:
	for event: InputEvent in InputMap.action_get_events(context_action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return
	var new_event := InputEventKey.new()
	new_event.physical_keycode = keycode
	InputMap.action_add_event(context_action, new_event)


func _ensure_joy_button(button: JoyButton) -> void:
	for event: InputEvent in InputMap.action_get_events(context_action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return
	var new_event := InputEventJoypadButton.new()
	new_event.button_index = button
	InputMap.action_add_event(context_action, new_event)


func _build_context_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	panel = PanelContainer.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -90)
	panel.custom_minimum_size = Vector2(440, 180)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.05, 0.94)
	style.border_color = Color(0.48, 0.82, 1.0, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	box.add_child(title_label)
	option_label = Label.new()
	option_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	option_label.add_theme_font_size_override("font_size", 18)
	option_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	box.add_child(option_label)


func _update_context_ui() -> void:
	title_label.text = context_name
	match context_name:
		"FAMILIAR":
			option_label.text = "◀ FOLLOW        ▲ STAY        ASSIST ▶"
		"MOUNT":
			option_label.text = "◀ DISMOUNT      ▲ CALL        DISMISS ▶"
		"ANIMAL STUDY":
			option_label.text = "◀ OBSERVE       ▲ FEED        SOOTHE ▶"
		_:
			option_label.text = "No contextual action nearby"


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func get_debug_data() -> Dictionary:
	return {"held": held, "wheel_open": wheel_open, "context": context_name, "hold_time": snappedf(hold_time, 0.01)}
