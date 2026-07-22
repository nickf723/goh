extends Node3D

const EnemyBrainScript = preload("res://scripts/enemies/enemy_brain.gd")
const EnemyOverheadHud = preload("res://scripts/combat/enemy_overhead_hud.gd")

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
@export var opening_message: String = (
	"Enemy Personality Lab: four goblins pursue harmless lane targets. "
	+ "Attacks are disabled and Grace is protected."
)

var previous_invulnerable: bool = false
var previous_invulnerability_timer: float = 0.0


func _ready() -> void:
	protect_grace()
	configure_lanes()

	# Enemy brains create their HUDs during child _ready() calls. Refresh all
	# four once the lab has finished assigning its lane-specific personalities.
	refresh_lab_huds.call_deferred()

	if show_opening_message:
		show_message(opening_message)


func _exit_tree() -> void:
	GameState.player_invulnerable = previous_invulnerable
	GameState.player_invulnerability_timer = previous_invulnerability_timer


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func protect_grace() -> void:
	previous_invulnerable = GameState.player_invulnerable
	previous_invulnerability_timer = GameState.player_invulnerability_timer

	GameState.player_invulnerable = true
	GameState.player_invulnerability_timer = INF


func configure_lanes() -> void:
	for lane_config: Dictionary in LANE_CONFIGS:
		configure_enemy_lane(lane_config)


func configure_enemy_lane(lane_config: Dictionary) -> void:
	var enemy_path: String = str(lane_config.get("enemy_path", ""))
	var enemy: CharacterBody3D = get_node_or_null(enemy_path) as CharacterBody3D

	if enemy == null:
		push_warning("Personality lab enemy not found: " + enemy_path)
		return

	var brain: Node = enemy.get_node_or_null("EnemyBrain")

	if brain == null:
		push_warning("EnemyBrain missing from: " + enemy_path)
		return

	var target_group: String = str(lane_config.get("target_group", ""))
	var target: Node = get_tree().get_first_node_in_group(target_group)

	if not target is Node3D:
		push_warning("Personality lab target not found: " + target_group)
		return

	# Keep the intended personality assignment.
	brain.set(
		"personality_id",
		str(lane_config.get("personality", "balanced"))
	)

	# Give this goblin its harmless lane target directly.
	brain.set("player_group", target_group)
	brain.set("player", target)

	# Laboratory goblins must never enter an attack.
	brain.set("default_attack", null)
	brain.set("attack_cooldown_timer", 0.0)
	brain.set("attack_commit_timer", 0.0)

	# Begin chasing immediately, even though the old target placement is
	# slightly outside the Goblin's normal detection radius.
	brain.set("state", EnemyBrainScript.EnemyState.CHASE)
	brain.set("state_timer", 0.0)
	brain.set("last_action_summary", "pursuing harmless lane target")

	brain.set("zone_debug_prints", false)
	brain.set("zone_awareness_radius", 7.0)


func refresh_lab_huds() -> void:
	for lane_config: Dictionary in LANE_CONFIGS:
		var enemy_path: String = str(lane_config.get("enemy_path", ""))
		var enemy: Node3D = get_node_or_null(enemy_path) as Node3D

		if enemy == null:
			continue

		var hud: EnemyOverheadHud = EnemyOverheadHud.ensure_for_target(enemy)

		if hud == null:
			push_warning("Personality lab HUD missing from: " + enemy_path)
			continue

		hud.show_personality_debug = true
		hud.bind_target(enemy)
		hud.refresh_now()


func show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(message)
		return

	print(message)
