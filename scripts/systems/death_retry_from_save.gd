extends Node

@export var retry_delay_seconds: float = 0.9
@export var defeated_message: String = "Grace falls. The last bed calls her back."
@export var no_save_message: String = "Grace falls. No saved rest has been found yet."
@export var reload_message: String = "Waking at the last save bed..."
@export var recapture_mouse_before_reload: bool = false

var is_retrying: bool = false


func _ready() -> void:
	if not GameState.player_defeated.is_connected(_on_player_defeated):
		GameState.player_defeated.connect(_on_player_defeated)


func _on_player_defeated() -> void:
	if is_retrying:
		return

	is_retrying = true
	Engine.time_scale = 1.0

	if not has_current_scene_save():
		show_message(no_save_message)
		is_retrying = false
		return

	show_message(defeated_message)
	await get_tree().create_timer(retry_delay_seconds).timeout

	if recapture_mouse_before_reload:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	show_message(reload_message)
	get_tree().reload_current_scene()


func has_current_scene_save() -> bool:
	var save_data: Dictionary = GameState.load_save_data()

	if save_data.is_empty():
		return false

	var saved_scene_path: String = str(save_data.get("scene_path", ""))
	var current_scene_path: String = GameState.get_current_scene_path()

	if saved_scene_path == "" or current_scene_path == "":
		return true

	return saved_scene_path == current_scene_path


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"retrying": is_retrying,
		"has_scene_save": has_current_scene_save(),
		"delay": retry_delay_seconds,
	}
