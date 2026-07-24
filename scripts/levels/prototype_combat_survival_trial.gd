extends Node3D
class_name PrototypeCombatSurvivalTrial

const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")

@export var opening_objective: String = "Survive two rounds. Read the red windup, Guard or Dodge, then punish the opening."
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
	show_message("Round 1: one readable Goblin. Red is windup; gold is impact.")
	advance_round()


func advance_round() -> void:
	round_index += 1
	match round_index:
		0:
			spawn_combatant(GoblinScene, Vector3(0.0, 0.7, -4.5), "Lesson Goblin", 5, 3)
			round_active = true
			show_message("ROUND 1 — Hold Guard to block, or tap it late for a Perfect Guard.")
		1:
			spawn_combatant(GoblinScene, Vector3(-3.0, 0.7, -4.8), "Pressure Goblin", 6, 3)
			spawn_combatant(GremlinScene, Vector3(3.0, 0.7, -3.5), "Flanking Gremlin", 4, 2)
			round_active = true
			show_message("ROUND 2 — Manage two threats. Guard is directional; Dodge escapes the flank.")
		_:
			victory = true
			round_active = false
			GameState.set_objective("Trial complete. RESET to run the defensive exchange again.")
			show_message("SURVIVED — defense, stamina, stance breaks, and counter-pressure completed one loop.")


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
		)

	if result_label != null:
		result_label.text = "GUARD • DODGE • LIGHT • HEAVY • LOCK-ON • RESET"


func resource_pair(resource_name: String) -> String:
	return str(GameState.get_stat(resource_name)) + " / " + str(GameState.get_stat("max_" + resource_name))


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
	}
