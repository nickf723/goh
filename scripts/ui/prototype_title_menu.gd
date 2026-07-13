extends Control

const TRIAL_ENTRY_SCENE: String = "res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn"

@onready var new_trial_button: Button = %NewTrialButton
@onready var continue_button: Button = %ContinueButton
@onready var controls_panel: Control = %ControlsPanel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	Engine.time_scale = 1.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	controls_panel.visible = false
	refresh_continue_state()
	new_trial_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_panel.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		hide_controls()
		get_viewport().set_input_as_handled()


func refresh_continue_state() -> void:
	var has_save: bool = GameState.has_method("has_save_file") and GameState.has_save_file()
	continue_button.disabled = not has_save

	if has_save:
		continue_button.tooltip_text = "Resume from the latest Church Trial save."
	else:
		continue_button.tooltip_text = "No Church Trial save exists yet."


func start_new_trial() -> void:
	status_label.text = "Beginning a new Church Trial..."
	GameState.reset_run()
	GameState.last_save_data = {}

	if FileAccess.file_exists(GameState.SAVE_SLOT_PATH):
		var remove_result: Error = DirAccess.remove_absolute(GameState.SAVE_SLOT_PATH)

		if remove_result != OK:
			status_label.text = "The old save could not be cleared. Error: " + str(remove_result)
			refresh_continue_state()
			return

	get_tree().change_scene_to_file(TRIAL_ENTRY_SCENE)


func continue_trial() -> void:
	var save_data: Dictionary = GameState.load_save_data()

	if save_data.is_empty():
		status_label.text = "No readable Church Trial save was found."
		refresh_continue_state()
		return

	var saved_scene_path: String = str(save_data.get("scene_path", TRIAL_ENTRY_SCENE))

	if saved_scene_path == "" or not ResourceLoader.exists(saved_scene_path):
		status_label.text = "The saved room is unavailable. Returning to the trial entrance."
		saved_scene_path = TRIAL_ENTRY_SCENE

	get_tree().change_scene_to_file(saved_scene_path)


func show_controls() -> void:
	controls_panel.visible = true
	%CloseControlsButton.grab_focus()


func hide_controls() -> void:
	controls_panel.visible = false
	%ControlsButton.grab_focus()


func quit_game() -> void:
	get_tree().quit()
