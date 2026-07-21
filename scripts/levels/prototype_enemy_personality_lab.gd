extends Node3D
class_name PrototypeEnemyPersonalityLab

const EnemyBrainScript = preload("res://scripts/enemies/enemy_brain.gd")

@export var opening_objective: String = "Observe four identical Goblins traverse identical lanes toward harmless targets."
@export var enable_editor_f8_reset: bool = true

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D

var lane_records: Array[Dictionary] = []
var initial_player_transform: Transform3D
var entry_health: int = 0
var entry_invulnerable: bool = false
var entry_invulnerability_timer: float = 0.0
var reset_count: int = 0


func _ready() -> void:
	add_to_group("enemy_personality_lab_director")
	add_to_group("debuggable")
	entry_health = GameState.get_stat("health")
	entry_invulnerable = GameState.player_invulnerable
	entry_invulnerability_timer = GameState.player_invulnerability_timer
	GameState.player_invulnerable = true
	GameState.player_invulnerability_timer = INF

	if player != null:
		initial_player_transform = player.global_transform

	configure_lanes()
	GameState.set_objective(opening_objective)


func configure_lanes() -> void:
	lane_records.clear()
	for lane_index: int in range(1, 5):
		var goblin: CharacterBody3D = get_node_or_null("Lanes/Lane%dGoblin" % lane_index) as CharacterBody3D
		var target: Node3D = get_node_or_null("Targets/Lane%dTarget" % lane_index) as Node3D
		if goblin == null or target == null:
			continue

		var brain: Node = goblin.get_node_or_null("EnemyBrain")
		if brain == null:
			continue

		brain.set("personality_id", "balanced")
		brain.set("default_attack", null)
		brain.set("player", target)
		brain.set("state", EnemyBrainScript.EnemyState.IDLE)
		brain.set("last_action_summary", "lane target assigned")
		lane_records.append({
			"goblin": goblin,
			"brain": brain,
			"target": target,
			"goblin_transform": goblin.global_transform,
			"target_transform": target.global_transform,
		})


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_lab()
		return

	if not enable_editor_f8_reset or not OS.has_feature("editor") or not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_lab()


func reset_lab() -> void:
	reset_count += 1
	GameState.set_stat("health", entry_health)
	GameState.player_invulnerable = true
	GameState.player_invulnerability_timer = INF

	if player != null:
		player.global_transform = initial_player_transform
		player.velocity = Vector3.ZERO
		if player.has_method("cancel_combat_motion"):
			player.call("cancel_combat_motion")
		if player.has_method("clear_lock_on"):
			player.call("clear_lock_on")

	for record: Dictionary in lane_records:
		var goblin: CharacterBody3D = record["goblin"] as CharacterBody3D
		var brain: Node = record["brain"] as Node
		var target: Node3D = record["target"] as Node3D
		goblin.global_transform = record["goblin_transform"] as Transform3D
		goblin.velocity = Vector3.ZERO
		target.global_transform = record["target_transform"] as Transform3D
		brain.set("player", target)
		brain.set("default_attack", null)
		brain.set("state", EnemyBrainScript.EnemyState.IDLE)
		brain.set("state_timer", 0.0)
		brain.set("attack_cooldown_timer", 0.0)
		brain.set("attack_commit_timer", 0.0)
		brain.set("last_action_summary", "lane target assigned")
		brain.set("zone_hesitation_timer", 0.0)
		var status_receiver: Node = goblin.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
			status_receiver.call("clear_all_statuses")
		var hit_receiver: Node = goblin.get_node_or_null("HitReceiver")
		if hit_receiver != null:
			if hit_receiver.has_method("reset_health"):
				hit_receiver.call("reset_health")
			if hit_receiver.has_method("reset_stance"):
				hit_receiver.call("reset_stance")
		var force_receiver: Node = goblin.get_node_or_null("ForceReceiver")
		if force_receiver != null and force_receiver.has_method("reset_forces"):
			force_receiver.call("reset_forces")
		var telegraph: Node = goblin.get_node_or_null("EnemyTelegraph")
		if telegraph != null and telegraph.has_method("reset"):
			telegraph.call("reset")

	GameState.set_objective(opening_objective)


func get_lane_records() -> Array[Dictionary]:
	return lane_records


func get_debug_data() -> Dictionary:
	return {
		"lab": "enemy_personality_foundation",
		"lanes": lane_records.size(),
		"resets": reset_count,
		"grace_invulnerable": GameState.player_invulnerable,
	}


func _exit_tree() -> void:
	GameState.player_invulnerable = entry_invulnerable
	GameState.player_invulnerability_timer = entry_invulnerability_timer
