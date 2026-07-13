extends Node3D
class_name EncounterController

signal encounter_started(encounter_id: String)
signal encounter_completed(encounter_id: String)

@export var definition: EncounterDefinition
@export var activate_on_ready: bool = false
@export var respawn_on_reset: bool = true
@export var reward_group_name: String = "encounter_reward"
@export var print_debug: bool = false

var is_active: bool = false
var is_complete: bool = false
var spawned_enemies: Array[Node3D] = []


func _ready() -> void:
	add_to_group("encounter_controller")
	add_to_group("debuggable")

	if definition == null:
		push_error("EncounterController has no EncounterDefinition: " + str(get_path()))
		return

	var errors: Array[String] = definition.validate_definition()
	for error_text: String in errors:
		push_error("EncounterDefinition: " + error_text)

	sync_from_game_state()
	if is_complete:
		return

	if activate_on_ready and errors.is_empty():
		activate_encounter()


func _process(_delta: float) -> void:
	if definition == null or is_complete:
		return

	if not is_active:
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		if player != null and player.global_position.distance_to(global_position) <= definition.activation_radius:
			activate_encounter()
		return

	prune_invalid_enemies()
	if spawned_enemies.is_empty():
		complete_encounter()


func sync_from_game_state() -> void:
	if definition == null or definition.completion_flag == "":
		return

	if not GameState.get_flag(definition.completion_flag):
		return

	clear_spawned_enemies()
	is_active = false
	is_complete = true
	unlock_reward_objects()


func activate_encounter() -> void:
	if definition == null or is_active or is_complete:
		return

	is_active = true
	spawned_enemies.clear()

	for index: int in range(definition.enemy_scenes.size()):
		var enemy_scene: PackedScene = definition.enemy_scenes[index]
		if enemy_scene == null:
			continue

		var enemy_instance: Node = enemy_scene.instantiate()
		if not enemy_instance is Node3D:
			enemy_instance.queue_free()
			continue

		var enemy: Node3D = enemy_instance as Node3D
		enemy.name = definition.encounter_id.capitalize().replace(" ", "") + "Enemy" + str(index + 1)
		add_child(enemy)
		enemy.position = definition.spawn_positions[index]
		enemy.rotation_degrees = definition.get_spawn_rotation(index)
		spawned_enemies.append(enemy)

	show_message(definition.display_name + " begins.")
	set_objective(definition.objective_on_start)
	encounter_started.emit(definition.encounter_id)

	if print_debug:
		print("Encounter activated: ", definition.get_debug_summary())

	if spawned_enemies.is_empty():
		complete_encounter()


func prune_invalid_enemies() -> void:
	var survivors: Array[Node3D] = []

	for enemy: Node3D in spawned_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue

		var hit_receiver: Node = enemy.get_node_or_null("HitReceiver")
		if hit_receiver != null:
			var current_health: Variant = hit_receiver.get("current_health")
			if current_health != null and int(current_health) <= 0:
				continue

		survivors.append(enemy)

	spawned_enemies = survivors


func complete_encounter() -> void:
	if is_complete:
		return

	is_complete = true
	is_active = false

	if definition != null:
		if definition.reward_mana > 0:
			GameState.restore_mana(definition.reward_mana)

		if definition.completion_flag != "":
			GameState.set_flag(definition.completion_flag, true)

		show_message(definition.completion_message)
		set_objective(definition.objective_on_complete)
		encounter_completed.emit(definition.encounter_id)

	unlock_reward_objects()


func unlock_reward_objects() -> void:
	for reward_object: Node in get_tree().get_nodes_in_group(reward_group_name):
		if reward_object.has_method("unlock"):
			reward_object.call("unlock")


func clear_spawned_enemies() -> void:
	for enemy: Node3D in spawned_enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()


func reset_encounter() -> void:
	clear_spawned_enemies()
	is_active = false
	is_complete = false

	if definition != null and definition.completion_flag != "":
		GameState.set_flag(definition.completion_flag, false)

	if respawn_on_reset and activate_on_ready:
		call_deferred("activate_encounter")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text)


func get_debug_data() -> Dictionary:
	return {
		"encounter": definition.encounter_id if definition != null else "missing",
		"active": is_active,
		"complete": is_complete,
		"remaining": spawned_enemies.size(),
	}
