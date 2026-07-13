extends Node3D
class_name PrototypeWeaponCombatArena

const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")

@export var opening_objective: String = "Equip Sword, Hammer, or Spear. Chain LIGHT attacks and branch into HEAVY finishers."
@export var opening_message: String = "Weapon Combat Arena online. Use LIGHT for chains and HEAVY for branching finishers."
@export var enable_editor_f8_reset: bool = true
@export var hud_refresh_interval: float = 0.05

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var weapon_controller: Node = get_node_or_null("Player/WeaponController")
@onready var enemy_container: Node3D = get_node_or_null("EnemyContainer") as Node3D
@onready var goblin_spawn: Node3D = get_node_or_null("GoblinSpawn") as Node3D
@onready var gremlin_spawn: Node3D = get_node_or_null("GremlinSpawn") as Node3D
@onready var weapon_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/WeaponLabel") as Label
@onready var attack_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/AttackLabel") as Label
@onready var queue_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/QueueLabel") as Label
@onready var cancel_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/CancelLabel") as Label

var initial_player_transform: Transform3D
var reset_count: int = 0
var hud_refresh_timer: float = 0.0


func _ready() -> void:
	add_to_group("combat_arena_director")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if player != null:
		initial_player_transform = player.global_transform

	if weapon_controller != null:
		weapon_controller.set("show_debug_hitboxes", true)
		if weapon_controller.has_signal("combo_state_changed"):
			weapon_controller.connect("combo_state_changed", Callable(self, "_on_combo_state_changed"))
		if weapon_controller.has_signal("weapon_changed"):
			weapon_controller.connect("weapon_changed", Callable(self, "_on_weapon_changed"))

	set_objective(opening_objective)
	show_message(opening_message)
	call_deferred("reset_arena")


func _process(delta: float) -> void:
	hud_refresh_timer -= delta
	if hud_refresh_timer > 0.0:
		return

	hud_refresh_timer = max(hud_refresh_interval, 0.02)
	refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return

	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_arena()


func reset_arena() -> void:
	reset_count += 1
	reset_player()
	reset_training_targets()
	respawn_enemies()
	refill_resources()
	set_objective(opening_objective)
	show_message("Combat arena reset #" + str(reset_count) + ". Practice Sword restored; all targets rebuilt.")
	refresh_hud()


func reset_player() -> void:
	if player == null:
		return

	player.global_transform = initial_player_transform
	player.velocity = Vector3.ZERO

	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")

	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")

	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null:
		if action_state.has_method("reset_for_respawn"):
			action_state.call("reset_for_respawn")
		elif action_state.has_method("clear_action_locks"):
			action_state.call("clear_action_locks")

	if weapon_controller != null:
		if weapon_controller.has_method("equip_weapon"):
			weapon_controller.call("equip_weapon", PracticeSword)
		if weapon_controller.has_method("reset_combo_chain"):
			weapon_controller.call("reset_combo_chain")


func reset_training_targets() -> void:
	for target: Node in get_tree().get_nodes_in_group("combat_arena_resettable"):
		if target != null and is_instance_valid(target) and target.has_method("reset_target"):
			target.call("reset_target")


func respawn_enemies() -> void:
	if enemy_container == null:
		return

	for child: Node in enemy_container.get_children():
		enemy_container.remove_child(child)
		child.queue_free()

	spawn_enemy(GoblinScene, goblin_spawn, "ArenaGoblin")
	spawn_enemy(GremlinScene, gremlin_spawn, "ArenaGremlin")


func spawn_enemy(scene: PackedScene, marker: Node3D, enemy_name: String) -> void:
	if scene == null or marker == null or enemy_container == null:
		return

	var enemy: Node = scene.instantiate()
	if not enemy is Node3D:
		enemy.queue_free()
		return

	enemy.name = enemy_name
	enemy_container.add_child(enemy)
	(enemy as Node3D).global_transform = marker.global_transform
	enemy.add_to_group("combat_arena_spawned")


func refill_resources() -> void:
	for resource_name: String in ["health", "stamina", "mana", "stance"]:
		var max_name: String = "max_" + resource_name
		GameState.set_stat(resource_name, GameState.get_stat(max_name))

	GameState.set_stat("focus", max(GameState.get_stat("focus"), 5))


func _on_combo_state_changed(_debug_data: Dictionary) -> void:
	refresh_hud()


func _on_weapon_changed(_weapon: WeaponDefinition) -> void:
	refresh_hud()


func refresh_hud() -> void:
	if weapon_controller == null or not weapon_controller.has_method("get_debug_data"):
		return

	var data: Dictionary = weapon_controller.call("get_debug_data")
	var chain_value: Variant = data.get("chain", [])
	var chain_text: String = "none"

	if chain_value is Array and (chain_value as Array).size() > 0:
		var chain_strings: Array[String] = []
		for entry: Variant in chain_value as Array:
			chain_strings.append(str(entry))
		chain_text = " → ".join(chain_strings)

	if weapon_label != null:
		weapon_label.text = "WEAPON  " + str(data.get("weapon", "none")) + "  [" + str(data.get("class", "none")).to_upper() + "]"

	if attack_label != null:
		attack_label.text = (
			"ATTACK  "
			+ str(data.get("attack", "none"))
			+ "  |  PHASE "
			+ str(data.get("phase", "idle")).to_upper()
			+ "  |  "
			+ str(data.get("elapsed", 0.0))
			+ "s"
		)

	if queue_label != null:
		queue_label.text = (
			"CHAIN  "
			+ chain_text
			+ "\nBUFFER  "
			+ str(data.get("queued", "none")).to_upper()
			+ "  |  COMBO "
			+ str(data.get("combo_time", 0.0))
			+ "s"
		)

	if cancel_label != null:
		cancel_label.text = (
			"CANCEL WINDOW  Spell: "
			+ ("OPEN" if bool(data.get("cast_cancel", false)) else "closed")
			+ "  |  Dodge: "
			+ ("OPEN" if bool(data.get("dodge_cancel", false)) else "closed")
			+ "\nACTIONS  •  LIGHT  •  HEAVY  •  LOCK-ON  •  SPELL  •  DODGE  •  RESET"
		)


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
		"arena": "weapon_combat_v0_6",
		"resets": reset_count,
		"spawned_enemies": get_tree().get_nodes_in_group("combat_arena_spawned").size(),
		"weapon": weapon_controller.call("get_debug_data") if weapon_controller != null and weapon_controller.has_method("get_debug_data") else {},
	}
