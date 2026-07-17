extends "res://scripts/ui/game_ui.gd"

const INPUT_MODE_KEYBOARD: String = "keyboard"
const INPUT_MODE_CONTROLLER: String = "controller"

var last_input_mode: String = INPUT_MODE_KEYBOARD
var current_prompt_text: String = ""
var prompt_is_visible: bool = false
var input_mode_label: Label


func _ready() -> void:
	super._ready()
	ensure_input_mode_label()
	update_input_mode_label()
	update_focus_help_copy()


func _input(event: InputEvent) -> void:
	var detected_mode: String = detect_input_mode(event)

	if detected_mode == "":
		return

	set_input_mode(detected_mode)


func show_prompt(text: String) -> void:
	current_prompt_text = text
	prompt_is_visible = true
	prompt_label.text = get_interact_prompt_prefix() + text
	prompt_label.visible = true


func hide_prompt() -> void:
	prompt_is_visible = false
	current_prompt_text = ""
	prompt_label.visible = false


func show_spell_focus_menu(menu_data: Dictionary) -> void:
	super.show_spell_focus_menu(menu_data)
	var selected_spell_name: String = str(menu_data.get("selected_spell_name", "None"))
	focus_spell_selected_label.text = "Selected: " + selected_spell_name
	update_focus_help_copy()


func detect_input_mode(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event.pressed:
			return INPUT_MODE_CONTROLLER
		return ""

	if event is InputEventJoypadMotion:
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if abs(motion_event.axis_value) >= 0.35:
			return INPUT_MODE_CONTROLLER
		return ""

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			return INPUT_MODE_KEYBOARD
		return ""

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.pressed:
			return INPUT_MODE_KEYBOARD
		return ""

	if event is InputEventMouseMotion:
		return INPUT_MODE_KEYBOARD

	return ""


func set_input_mode(mode: String) -> void:
	if mode == "":
		return

	if mode == last_input_mode:
		return

	last_input_mode = mode
	update_input_mode_label()
	update_focus_help_copy()

	if prompt_is_visible:
		show_prompt(current_prompt_text)


func ensure_input_mode_label() -> void:
	if input_mode_label != null:
		return

	input_mode_label = Label.new()
	input_mode_label.name = "InputModeLabel"
	input_mode_label.anchor_left = 1.0
	input_mode_label.anchor_top = 0.0
	input_mode_label.anchor_right = 1.0
	input_mode_label.anchor_bottom = 0.0
	input_mode_label.offset_left = -270.0
	input_mode_label.offset_top = 74.0
	input_mode_label.offset_right = -24.0
	input_mode_label.offset_bottom = 98.0
	input_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	input_mode_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.9, 0.78))
	input_mode_label.add_theme_font_size_override("font_size", 12)
	add_child(input_mode_label)


func update_input_mode_label() -> void:
	ensure_input_mode_label()
	input_mode_label.text = "Input: " + get_input_mode_display_name()


func update_focus_help_copy() -> void:
	if focus_spell_help_label == null:
		return

	if last_input_mode == INPUT_MODE_CONTROLLER:
		focus_spell_help_label.text = "D-pad: choose   RT/A/B: equip   Menu release: close"
	else:
		focus_spell_help_label.text = "Arrows/wheel: choose   Q/Enter/Space/click: equip   Release Tab: close"


func get_interact_prompt_prefix() -> String:
	if last_input_mode == INPUT_MODE_CONTROLLER:
		return "B: "

	return "E: "


func get_input_mode_display_name() -> String:
	if last_input_mode == INPUT_MODE_CONTROLLER:
		return "Controller"

	return "Keyboard / Mouse"
