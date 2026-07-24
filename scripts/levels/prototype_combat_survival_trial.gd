extends Node3D
class_name PrototypeCombatSurvivalTrial

const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")
const LootDropperScript = preload("res://scripts/items/loot_dropper.gd")
const GoblinLootTable: LootTable = preload("res://data/loot/survival_enemy_supplies.tres")
const GremlinLootTable: LootTable = preload("res://data/loot/survival_gremlin_supplies.tres")

@export var opening_objective: String = "Break supply crates, defeat enemies for drops, survive two rounds, then choose one reward from the unlocked chest."
@export var enable_editor_f8_reset: bool = true
@export_range(0.2, 5.0, 0.1) var between_round_seconds: float = 1.25

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var enemy_container: Node3D = get_node_or_null("Enemies") as Node3D
@onready var wave_label: Label = get_node_or_null("TrialHUD/Panel/Margin/VBox/WaveLabel") as Label
@onready var defense_label: Label = get_node_or_null("TrialHUD/Panel/Margin/VBox/DefenseLabel") as Label
@onready var resource_label: Label = get_node_or_null("TrialHUD/Panel/Margin/VBox/ResourceLabel") as Label
@onready var result_label: Label = get_node_or_null("TrialHUD/Panel/Margin/VBox/ResultLabel") as Label
@onready var defense_controller: PlayerDefenseController = get_node_or_null("Player/PlayerDefenseController") as PlayerDefenseController
@onready var action_state: PlayerActionState = get_node_or_null("Player/PlayerActionState") as PlayerActionState
@onready var resource_controller: PlayerResourceController = get_node_or_null("Player/PlayerResourceController") as PlayerResourceController
@onready var quick_item_controller: PlayerQuickItemController = get_node_or_null("Player/PlayerQuickItemController") as PlayerQuickItemController
@onready var reward_chest: RewardChoiceChest = get_node_or_null("RewardChoiceChest") as RewardChoiceChest

var initial_player_transform: Transform3D
var round_index: int = -1
var round_active: bool = false
var between_round_timer: float = 0.0
var victory: bool = false
var defeat: bool = false
var last_defense_message: String = "READY — tap Guard on the red windup for a Perfect Guard."


func _ready() -> void:
	add_to_group("combat_survival_trial")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if player != null:
		initial_player_transform = player.global_transform
	if defense_controller != null:
		defense_controller.attack_blocked.connect(_on_defense_result)
		defense_controller.perfect_guarded.connect(_on_defense_result)
		defense_controller.guard_broken.connect(_on_defense_result)
		defense_controller.player_hit.connect(_on_defense_result)
	if not GameState.player_defeated.is_connected(_on_player_defeated):
		GameState.player_defeated.connect(_on_player_defeated)

	reset_trial()


func _exit_tree() -> void:
	if GameState.player_defeated.is_connected(_on_player_defeated):
		GameState.player_defeated.disconnect(_on_player_defeated)


func _process(delta: float) -> void:
	refresh_hud()
	if victory or defeat or not round_active:
		return
	if count_living_enemies() > 0:
		between_round_timer = 0.0
		return

	if between_round_timer <= 0.0:
		between_round_timer = between_round_seconds
	between_round_timer -= delta
	if between_round_timer > 0.0:
		return

	round_active = false
	advance_round()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_trial()


func reset_trial() -> void:
	clear_enemies()
	round_index = -1
	round_active = false
	between_round_timer = 0.0
	victory = false
	defeat = false
	last_defense_message = "READY — tap Guard on the red windup for a Perfect Guard."

	GameState.restore_rest_resources()
	GameState.set_inventory_count("oil_flask", 0)
	GameState.set_inventory_count("noise_maker", 0)
	for pickup: Node in get_tree().get_nodes_in_group("world_item_pickup"):
		if bool(pickup.get("runtime_drop")):
			pickup.queue_free()
		elif pickup.has_method("reset_pickup"):
			pickup.call("reset_pickup")
	for container: Node in get_tree().get_nodes_in_group("breakable_supply_container"):
		if container.has_method("reset_container"):
			container.call("reset_container")
	if reward_chest != null:
		reward_chest.reset_chest()
	GameState.player_invulnerable = false
	GameState.player_invulnerability_timer = 0.0
	if action_state != null:
		action_state.reset_for_respawn()
	if defense_controller != null:
		defense_controller.reset_defense()
	if resource_controller != null:
		resource_controller.reset_recovery_state()
	if player != null:
		player.global_transform = initial_player_transform
		player.velocity = Vector3.ZERO

	GameState.set_objective(opening_objective)
	show_message("BREAK • FIGHT • LOOT — smash the side crates, defeat enemies for drops, and claim the chest after Round 2.")
	advance_round()


func advance_round() -> void:
	round_index += 1
	match round_index:
		0:
			spawn_combatant(GoblinScene, Vector3(0.0, 0.7, -4.5), "Lesson Goblin", 5, 3)
			round_active = true
			show_message("ROUND 1 — Defend first. Oil prepares Fire combos; Noise creates evidence where it lands.")
		1:
			spawn_combatant(GoblinScene, Vector3(-3.0, 0.7, -4.8), "Pressure Goblin", 6, 3)
			spawn_combatant(GremlinScene, Vector3(3.0, 0.7, -3.5), "Flanking Gremlin", 4, 2)
			round_active = true
			show_message("ROUND 2 — Manage two threats. A hit interrupts the Flask without consuming a charge.")
		_:
			victory = true
			round_active = false
			if reward_chest != null:
				reward_chest.unlock_chest()
			GameState.set_objective("Reward unlocked. Open the gold chest and choose one supply cache.")
			show_message("SURVIVED — the reward chest is unlocked. Open it and choose ONE supply cache.")


func spawn_combatant(
	scene: PackedScene,
	spawn_position: Vector3,
	display_name: String,
	health: int,
	stance: int
) -> void:
	if enemy_container == null or scene == null:
		return
	var enemy: Node3D = scene.instantiate() as Node3D
	if enemy == null:
		return
	enemy.name = display_name.replace(" ", "")
	enemy_container.add_child(enemy)
	enemy.global_position = spawn_position
	if player != null:
		var target: Vector3 = player.global_position
		target.y = enemy.global_position.y
		enemy.look_at(target, Vector3.UP)

	var receiver: Node = enemy.get_node_or_null("HitReceiver")
	if receiver != null:
		receiver.set("target_name", display_name)
		receiver.set("hit_mode", 3)
		receiver.set("max_health", health)
		receiver.set("current_health", health)
		receiver.set("max_stance", stance)
		receiver.set("current_stance", stance)
		receiver.set("regenerates_stance", true)
		receiver.set("disappears_when_defeated", true)
		if receiver.has_method("refresh_overhead_hud"):
			receiver.call("refresh_overhead_hud")

	var dropper: LootDropper = LootDropperScript.new() as LootDropper
	dropper.name = "LootDropper"
	dropper.loot_table = GremlinLootTable if scene == GremlinScene else GoblinLootTable
	dropper.auto_collect_drops = true
	dropper.scatter_radius = 0.9
	dropper.loot_spawned.connect(_on_loot_spawned.bind(display_name))
	enemy.add_child(dropper)


func _on_loot_spawned(results: Array[Dictionary], _pickups: Array[WorldItemPickup], source_name: String) -> void:
	var summaries: Array[String] = []
	for result: Dictionary in results:
		var item: QuickItemDefinition = result.get("item_definition") as QuickItemDefinition
		if item != null:
			summaries.append(item.short_label + " ×" + str(result.get("quantity", 0)))
	if summaries.is_empty():
		last_defense_message = source_name + " dropped nothing."
	else:
		last_defense_message = source_name + " dropped " + ", ".join(summaries) + "."


func clear_enemies() -> void:
	if enemy_container == null:
		return
	for child: Node in enemy_container.get_children():
		child.queue_free()


func count_living_enemies() -> int:
	if enemy_container == null:
		return 0
	var living: int = 0
	for enemy: Node in enemy_container.get_children():
		if not enemy.is_queued_for_deletion():
			living += 1
	return living


func _on_defense_result(result: Dictionary) -> void:
	last_defense_message = str(result.get("message", result.get("outcome", "resolved")))


func _on_player_defeated() -> void:
	defeat = true
	round_active = false
	last_defense_message = "DEFEATED — use RESET and watch the windup, not the enemy's idle motion."
	GameState.set_objective("Grace was defeated. RESET the trial and try a later Guard or a Dodge.")
	show_message(last_defense_message)


func refresh_hud() -> void:
	if wave_label != null:
		if victory:
			wave_label.text = "COMBAT SURVIVAL — COMPLETE"
		elif defeat:
			wave_label.text = "COMBAT SURVIVAL — DEFEATED"
		else:
			wave_label.text = "ROUND " + str(round_index + 1) + " / 2    ENEMIES " + str(count_living_enemies())

	if defense_label != null:
		var state_text: String = "READY"
		if defense_controller != null:
			var data: Dictionary = defense_controller.get_debug_data()
			if bool(data.get("guarding", false)):
				state_text = "GUARDING"
				if float(data.get("perfect_window", 0.0)) > 0.0:
					state_text = "PERFECT WINDOW"
			elif bool(data.get("hit_reaction", 0.0) > 0.0):
				state_text = "RECOVERING"
		defense_label.text = "DEFENSE " + state_text + "    " + last_defense_message

	if resource_label != null:
		resource_label.text = (
			"HEALTH " + resource_pair("health")
			+ "    STAMINA " + resource_pair("stamina")
			+ "    STANCE " + resource_pair("stance")
			+ "    FLASK ×" + str(GameState.get_inventory_count("healing_flask"))
			+ "    OIL ×" + str(GameState.get_inventory_count("oil_flask"))
			+ "    NOISE ×" + str(GameState.get_inventory_count("noise_maker"))
		)

	if result_label != null:
		result_label.text = "BREAK CRATE • DEFEAT • COLLECT DROP • OPEN CHEST • CHOOSE ONE"


func resource_pair(resource_name: String) -> String:
	return str(GameState.get_stat(resource_name)) + " / " + str(GameState.get_stat("max_" + resource_name))


func get_flask_charges() -> int:
	if quick_item_controller == null:
		return 0
	return quick_item_controller.get_slot_charges(PlayerQuickItemController.SLOT_UP)


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)


func get_debug_data() -> Dictionary:
	return {
		"round": round_index + 1,
		"living_enemies": count_living_enemies(),
		"victory": victory,
		"defeat": defeat,
		"last_defense": last_defense_message,
		"reward_chest": reward_chest.get_debug_data() if reward_chest != null else {},
	}
