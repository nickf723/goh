extends Node3D

const RewardAltarScene: PackedScene = preload("res://scenes/actors/interactables/church_trial_reward_altar.tscn")
const TransitionAreaScene: PackedScene = preload("res://scenes/actors/interactables/level_exit.tscn")
const ChurchEntryDressingScene: PackedScene = preload("res://scenes/environment/church/church_entry_dressing_v1.tscn")
const ChurchCombatWingDressingScene: PackedScene = preload("res://scenes/environment/church/church_combat_wing_dressing_v1.tscn")
const ChamberOfAccordScene: PackedScene = preload("res://scenes/environment/church/church_trial_chamber_of_accord_v1.tscn")
const GuardTestEnemyScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const PROTOTYPE_SAVE_PATH: String = "user://goh_save_slot_1.json"

@export var opening_objective: String = "Church Trial: save, clear combat, solve the Chamber of Accord, cross the echo path, defeat the armor, claim the sigil, then exit."
@export var opening_message: String = "The Church Trial tests force, understanding, perception, and resolve."
@export var apply_save_on_ready: bool = true
@export var add_reward_altar: bool = true
@export var reward_altar_position: Vector3 = Vector3(0.0, 0.15, 112.5)
@export var enable_dev_save_reset: bool = true

@export_group("Dev Shortcuts")
@export var dev_grant_charged_firebolt_on_ready: bool = true
@export var dev_charged_firebolt_message: String = "Prototype shortcut: Charged Firebolt is unlocked for immediate testing."

@export_group("Art Dressing")
@export var add_entry_art_dressing: bool = true
@export var add_combat_art_dressing: bool = true
@export var add_chamber_of_accord: bool = true

@export_group("Room Flow")
@export var add_sound_transition: bool = true
@export_file("*.tscn") var sound_scene_path: String = "res://scenes/levels/prototypes/prototype_sound_reveal_bridge_v1.tscn"
@export var sound_transition_position: Vector3 = Vector3(0.0, 1.0, 70.0)
@export var sound_transition_scale: Vector3 = Vector3(12.0, 1.0, 1.25)
@export var sound_transition_message: String = "The Chamber of Accord yields. The Church's next chamber listens for what sight cannot find."
@export var sound_transition_objective: String = "Use Sound Pulse to reveal the hidden path."

@export_group("Guard Testing")
@export var add_guard_test_enemy: bool = true
@export var guard_test_enemy_position: Vector3 = Vector3(4.0, 0.85, 112.0)
@export var guard_test_enemy_offset_from_player: Vector3 = Vector3(3.0, 0.0, 0.0)
@export var guard_test_enemy_message: String = "A Guard Test Goblin appears nearby. Let it strike once to test Guard."


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	install_chamber_of_accord()
	connect_guard_test_signals()
	spawn_entry_art_dressing()
	spawn_combat_art_dressing()
	spawn_reward_altar()
	spawn_sound_transition()
	configure_final_exit()
	spawn_guard_test_enemy_if_ready()
	await get_tree().process_frame

	if apply_save_on_ready and GameState.apply_save_for_current_scene():
		set_objective(GameState.current_objective)
		var resume_message: String = get_resume_message()
		var resume_dev_message: String = grant_dev_charged_firebolt_if_enabled()
		if resume_dev_message != "":
			resume_message += " " + resume_dev_message
		show_message(resume_message)
		spawn_guard_test_enemy_if_ready()
		return

	set_objective(opening_objective)
	var start_message: String = get_opening_message()
	var start_dev_message: String = grant_dev_charged_firebolt_if_enabled()
	if start_dev_message != "":
		start_message += " " + start_dev_message
	show_message(start_message)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor"):
		return

	if not enable_dev_save_reset:
		return

	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	if key_event.physical_keycode != KEY_F8:
		return

	get_viewport().set_input_as_handled()
	clear_prototype_save_and_restart()


func connect_guard_test_signals() -> void:
	var unlock_callable: Callable = Callable(self, "_on_game_state_unlock_changed")
	if not GameState.unlock_changed.is_connected(unlock_callable):
		GameState.unlock_changed.connect(unlock_callable)

	var stat_callable: Callable = Callable(self, "_on_game_state_stat_changed")
	if not GameState.stat_changed.is_connected(stat_callable):
		GameState.stat_changed.connect(stat_callable)


func _on_game_state_unlock_changed(unlock_id: String, value: bool) -> void:
	if unlock_id != "armor_trial_blessing":
		return

	if not value:
		return

	call_deferred("spawn_guard_test_enemy_if_ready")


func _on_game_state_stat_changed(stat_name: String, value: int) -> void:
	if stat_name != "guard":
		return

	if value <= 0:
		return

	call_deferred("spawn_guard_test_enemy_if_ready")


func grant_dev_charged_firebolt_if_enabled() -> String:
	if not OS.has_feature("editor"):
		return ""

	if not dev_grant_charged_firebolt_on_ready:
		return ""

	if not GameState.has_method("grant_unlock"):
		return ""

	if GameState.has_method("has_unlock") and GameState.has_unlock("charged_firebolt"):
		return ""

	GameState.grant_unlock("charged_firebolt", {
		"source": "Prototype shortcut",
	})
	return dev_charged_firebolt_message


func get_opening_message() -> String:
	if OS.has_feature("editor") and enable_dev_save_reset:
		return opening_message + " Press F8 to clear the prototype save and restart fresh."

	return opening_message


func get_resume_message() -> String:
	var message: String = "Grace resumes from saved progress."

	if OS.has_feature("editor") and enable_dev_save_reset:
		message += " Press F8 to clear this prototype save and restart fresh."

	return message


func clear_prototype_save_and_restart() -> void:
	GameState.reset_run()

	if FileAccess.file_exists(PROTOTYPE_SAVE_PATH):
		var remove_result: Error = DirAccess.remove_absolute(PROTOTYPE_SAVE_PATH)

		if remove_result != OK:
			show_message("Could not clear prototype save: " + str(remove_result))
			return
	set_objective(opening_objective)
	show_message("Prototype save cleared. Restarting the Church Trial from the beginning.")

	await get_tree().create_timer(0.15).timeout
	get_tree().reload_current_scene()


func install_chamber_of_accord() -> void:
	if not add_chamber_of_accord:
		return

	var puzzle_room: Node3D = get_node_or_null("Room3Puzzle") as Node3D
	if puzzle_room == null:
		return
	if puzzle_room.get_node_or_null("ChamberOfAccord") != null:
		return

	# The packed room replaces the original pair of elemental cubes at runtime.
	# Their reusable scripts remain available to other prototypes, while the
	# Church Trial now exercises the production mechanism grammar.
	for legacy_name: String in [
		"PuzzleHintWater",
		"PuzzleHintOil",
		"WaterLockTarget",
		"FireLockTarget",
		"PuzzleGate",
		"ElementLockController",
	]:
		var legacy_node: Node = puzzle_room.get_node_or_null(legacy_name)
		if legacy_node != null:
			legacy_node.free()

	var chamber: ChurchTrialChamberOfAccord = (
		ChamberOfAccordScene.instantiate() as ChurchTrialChamberOfAccord
	)
	if chamber == null:
		push_warning("Church Trial could not instantiate the Chamber of Accord.")
		return
	chamber.name = "ChamberOfAccord"
	puzzle_room.add_child(chamber)
	chamber.position = Vector3.ZERO


func spawn_entry_art_dressing() -> void:
	if not add_entry_art_dressing:
		return

	var entry_room: Node3D = get_node_or_null("Room1Entry") as Node3D

	if entry_room == null:
		return

	if entry_room.get_node_or_null("ChurchEntryDressingV1") != null:
		return

	var dressing: Node3D = ChurchEntryDressingScene.instantiate() as Node3D

	if dressing == null:
		return

	dressing.name = "ChurchEntryDressingV1"
	entry_room.add_child(dressing)
	dressing.position = Vector3.ZERO


func spawn_combat_art_dressing() -> void:
	if not add_combat_art_dressing:
		return

	var combat_room: Node3D = get_node_or_null("Room2Combat") as Node3D

	if combat_room == null:
		return

	if combat_room.get_node_or_null("ChurchCombatWingDressingV1") != null:
		return

	var dressing: Node3D = ChurchCombatWingDressingScene.instantiate() as Node3D

	if dressing == null:
		return

	dressing.name = "ChurchCombatWingDressingV1"
	combat_room.add_child(dressing)
	dressing.position = Vector3.ZERO


func spawn_reward_altar() -> void:
	if not add_reward_altar:
		return

	if get_node_or_null("ChurchTrialRewardAltar") != null:
		return

	var altar: Node3D = RewardAltarScene.instantiate() as Node3D

	if altar == null:
		return

	altar.name = "ChurchTrialRewardAltar"
	add_child(altar)
	altar.global_position = reward_altar_position


func spawn_sound_transition() -> void:
	if not add_sound_transition:
		return

	if sound_scene_path == "":
		return

	if get_node_or_null("SoundTrialTransition") != null:
		return

	var transition: Node3D = TransitionAreaScene.instantiate() as Node3D

	if transition == null:
		return

	transition.name = "SoundTrialTransition"
	transition.scale = sound_transition_scale
	transition.set("completion_message", sound_transition_message)
	transition.set("objective_after", sound_transition_objective)
	transition.set("next_scene_path", sound_scene_path)
	transition.set("triggers_on_touch", true)

	var transition_visual: Node3D = transition.get_node_or_null("MeshInstance3D") as Node3D
	if transition_visual != null:
		transition_visual.visible = false

	add_child(transition)
	transition.global_position = sound_transition_position


func spawn_guard_test_enemy_if_ready() -> void:
	if not add_guard_test_enemy:
		return

	if get_node_or_null("GuardTestGoblin") != null:
		return

	if not GameState.has_method("has_unlock") or not GameState.has_unlock("armor_trial_blessing"):
		return

	if GameState.get_stat("guard") <= 0:
		return

	var enemy: Node3D = GuardTestEnemyScene.instantiate() as Node3D

	if enemy == null:
		return

	enemy.name = "GuardTestGoblin"
	add_child(enemy)
	enemy.global_position = get_guard_test_enemy_position()
	show_message(guard_test_enemy_message)


func get_guard_test_enemy_position() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D

	if player != null:
		return player.global_position + guard_test_enemy_offset_from_player

	return guard_test_enemy_position


func configure_final_exit() -> void:
	var final_exit: Node = find_child_named(self, "LevelExit")

	if final_exit == null:
		return

	if "completion_message" in final_exit:
		final_exit.set("completion_message", "Church Trial complete. Grace carries the Church Trial Sigil beyond the reward chamber.")

	if "objective_after" in final_exit:
		final_exit.set("objective_after", "Church Trial complete.")

	if "required_key_item_id" in final_exit:
		final_exit.set("required_key_item_id", "church_trial_sigil")

	if "missing_key_item_message" in final_exit:
		final_exit.set("missing_key_item_message", "The final door waits for the Church Trial Sigil.")

	if "missing_key_item_objective" in final_exit:
		final_exit.set("missing_key_item_objective", "Claim the Church Trial Sigil from the reward altar.")


func find_child_named(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root

	for child: Node in root.get_children():
		var found: Node = find_child_named(child, target_name)
		if found != null:
			return found

	return null


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
