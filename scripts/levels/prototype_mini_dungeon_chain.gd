extends Node3D

const SaveBedScene = preload("res://scenes/actors/interactables/save_bed.tscn")
const DeathRetryFromSaveScript = preload("res://scripts/systems/death_retry_from_save.gd")

@export var opening_objective: String = "Enter the trial chain. Clear the combat room, then solve the element lock."
@export var opening_message: String = "Prototype mini-dungeon: shrine, combat, element lock."
@export var apply_save_on_ready: bool = true
@export var add_entry_save_bed: bool = true
@export var enable_death_retry_from_save: bool = true
@export var entry_save_bed_position: Vector3 = Vector3(4.75, 0.12, -5.0)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	spawn_entry_save_bed()
	spawn_death_retry_controller()
	await get_tree().process_frame

	if apply_save_on_ready and GameState.apply_save_for_current_scene():
		set_objective(GameState.current_objective)
		show_message("Grace wakes at the last save bed.")
		return

	set_objective(opening_objective)
	show_message(opening_message)


func spawn_entry_save_bed() -> void:
	if not add_entry_save_bed:
		return

	if get_node_or_null("EntrySaveBed") != null:
		return

	var bed: Node3D = SaveBedScene.instantiate() as Node3D

	if bed == null:
		return

	bed.name = "EntrySaveBed"
	add_child(bed)
	bed.global_position = entry_save_bed_position

	if "bed_id" in bed:
		bed.set("bed_id", "mini_dungeon_entry_bed")

	if "bed_display_name" in bed:
		bed.set("bed_display_name", "Mini-Dungeon Entry Bed")


func spawn_death_retry_controller() -> void:
	if not enable_death_retry_from_save:
		return

	if get_node_or_null("DeathRetryFromSave") != null:
		return

	var retry_controller: Node = Node.new()
	retry_controller.name = "DeathRetryFromSave"
	retry_controller.set_script(DeathRetryFromSaveScript)
	add_child(retry_controller)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
