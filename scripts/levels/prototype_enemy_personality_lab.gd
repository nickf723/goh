extends Node3D

const LANE_CONFIGS: Array[Dictionary] = [
	{
		"enemy_path": "Lanes/CautiousGoblin",
		"target_group": "personality_lab_cautious_target",
		"personality": "cautious",
	},
	{
		"enemy_path": "Lanes/BoldGoblin",
		"target_group": "personality_lab_bold_target",
		"personality": "bold",
	},
	{
		"enemy_path": "Lanes/SkittishGoblin",
		"target_group": "personality_lab_skittish_target",
		"personality": "skittish",
	},
	{
		"enemy_path": "Lanes/BruteGoblin",
		"target_group": "personality_lab_brute_target",
		"personality": "brute",
	},
]

@export var show_opening_message: bool = true
@export var opening_message: String = "Enemy Personality Lab: four identical goblins chase lane targets through the same poison cloud. Compare cautious, bold, skittish, and brute steering."


func _ready() -> void:
	configure_lanes()
	if show_opening_message:
		show_message(opening_message)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_tree().reload_current_scene()


func configure_lanes() -> void:
	for lane_config: Dictionary in LANE_CONFIGS:
		configure_enemy_lane(lane_config)


func configure_enemy_lane(lane_config: Dictionary) -> void:
	var enemy: Node = get_node_or_null(str(lane_config.get("enemy_path", "")))
	if enemy == null:
		return

	var brain: Node = enemy.get_node_or_null("EnemyBrain")
	if brain == null:
		return

	brain.set("personality_id", str(lane_config.get("personality", "balanced")))
	brain.set("player_group", str(lane_config.get("target_group", "player")))
	brain.set("player", null)
	brain.set("zone_debug_prints", false)
	brain.set("zone_awareness_radius", 7.0)

	if brain.has_method("refresh_player"):
		brain.call_deferred("refresh_player")


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(message)
		return
	print(message)
