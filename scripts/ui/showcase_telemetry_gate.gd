extends Node
class_name ShowcaseTelemetryGate


@export var telemetry_toggle_key: Key = KEY_F2
@export var show_telemetry_on_start: bool = false

var actor: CharacterBody3D
var showcase_root: PrototypeAnimationShowcaseLab
var telemetry_panel: Control
var telemetry_visible: bool = false
var setup_complete: bool = false
var setup_attempts: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	call_deferred("_finish_setup")
	add_to_group("showcase_telemetry_gate")


func _finish_setup() -> void:
	setup_attempts += 1
	showcase_root = _find_showcase_root()
	if showcase_root == null:
		if setup_attempts < 4:
			call_deferred("_finish_setup")
		else:
			queue_free()
		return

	var label_value: Variant = showcase_root.get("status_label")
	if not label_value is Label:
		if setup_attempts < 8:
			call_deferred("_finish_setup")
		return

	var label: Label = label_value as Label
	telemetry_panel = label.get_parent() as Control
	if telemetry_panel == null:
		return
	setup_complete = true
	set_telemetry_visible(show_telemetry_on_start, false)


func _unhandled_input(event: InputEvent) -> void:
	if not setup_complete or telemetry_panel == null:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if (
		key_event.physical_keycode != telemetry_toggle_key
		and key_event.keycode != telemetry_toggle_key
	):
		return
	set_telemetry_visible(not telemetry_visible, true)
	get_viewport().set_input_as_handled()


func set_telemetry_visible(value: bool, show_feedback: bool = true) -> void:
	telemetry_visible = value
	if telemetry_panel != null:
		telemetry_panel.visible = telemetry_visible
	if show_feedback:
		_show_message(
			"Showcase telemetry shown."
			if telemetry_visible
			else "Showcase telemetry hidden."
		)


func _find_showcase_root() -> PrototypeAnimationShowcaseLab:
	var cursor: Node = actor.get_parent() if actor != null else get_parent()
	while cursor != null:
		if cursor is PrototypeAnimationShowcaseLab:
			return cursor as PrototypeAnimationShowcaseLab
		cursor = cursor.get_parent()
	var current_scene: Node = get_tree().current_scene
	if current_scene is PrototypeAnimationShowcaseLab:
		return current_scene as PrototypeAnimationShowcaseLab
	return null


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)


func get_debug_data() -> Dictionary:
	return {
		"setup_complete": setup_complete,
		"showcase_found": showcase_root != null,
		"telemetry_visible": telemetry_visible,
		"panel_visible": telemetry_panel != null and telemetry_panel.visible,
		"toggle": "F2",
	}
