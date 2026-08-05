extends Node3D

signal lab_reset

const EnemyBrainScript = preload("res://scripts/enemies/enemy_brain.gd")
const EnemyOverheadHud = preload("res://scripts/combat/enemy_overhead_hud.gd")

const LANE_CONFIGS: Array[Dictionary] = [
	{
		"enemy_path": "Lanes/CautiousGoblin",
		"target_group": "personality_lab_cautious_target",
		"personality": "cautious",
		"hazard_path": "Hazards/CautiousPoison",
	},
	{
		"enemy_path": "Lanes/BoldGoblin",
		"target_group": "personality_lab_bold_target",
		"personality": "bold",
		"hazard_path": "Hazards/BoldPoison",
	},
	{
		"enemy_path": "Lanes/SkittishGoblin",
		"target_group": "personality_lab_skittish_target",
		"personality": "skittish",
		"hazard_path": "Hazards/SkittishPoison",
	},
	{
		"enemy_path": "Lanes/BruteGoblin",
		"target_group": "personality_lab_brute_target",
		"personality": "brute",
		"hazard_path": "Hazards/BrutePoison",
	},
]

@export var show_opening_message: bool = true
@export var opening_message: String = (
	"Enemy Personality Lab baseline: four harmless Goblins immediately traverse "
	+ "identical lanes. Combat is disabled; personality tuning is deferred."
)

var previous_invulnerable: bool = false
var previous_invulnerability_timer: float = 0.0
var grace_protection_active: bool = false
var initial_lane_states: Dictionary = {}
var initial_hazard_states: Dictionary = {}


func _ready() -> void:
	protect_grace()
	capture_initial_state()
	configure_lanes()

	# Enemy brains create their HUDs during child _ready() calls. Refresh all
	# four once the lab has assigned its lane-specific personality metadata.
	refresh_lab_huds.call_deferred()

	if show_opening_message:
		show_message(opening_message)


func _exit_tree() -> void:
	if not grace_protection_active:
		return

	GameState.player_invulnerable = previous_invulnerable
	GameState.player_invulnerability_timer = previous_invulnerability_timer
	grace_protection_active = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_lab()


func protect_grace() -> void:
	if grace_protection_active:
		return

	previous_invulnerable = GameState.player_invulnerable
	previous_invulnerability_timer = GameState.player_invulnerability_timer

	GameState.player_invulnerable = true
	GameState.player_invulnerability_timer = INF
	grace_protection_active = true


func capture_initial_state() -> void:
	initial_lane_states.clear()
	initial_hazard_states.clear()

	for lane_config: Dictionary in LANE_CONFIGS:
		var enemy_path: String = str(lane_config.get("enemy_path", ""))
		var enemy: CharacterBody3D = get_node_or_null(enemy_path) as CharacterBody3D
		if enemy != null:
			initial_lane_states[enemy_path] = {
				"transform": enemy.transform,
				"visible": enemy.visible,
			}

		var hazard_path: String = str(lane_config.get("hazard_path", ""))
		var hazard: Node3D = get_node_or_null(hazard_path) as Node3D
		if hazard != null:
			initial_hazard_states[hazard_path] = {
				"transform": hazard.transform,
				"radius": float(hazard.get("radius")),
				"lifetime": float(hazard.get("lifetime")),
				"visible": hazard.visible,
			}


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

	if brain.has_method("cancel_current_action"):
		brain.call("cancel_current_action", "personality lab baseline")

	brain.set("personality_id", str(lane_config.get("personality", "balanced")))
	brain.set("player_group", target_group)
	brain.set("player", target as Node3D)

	# The laboratory isolates movement and target acquisition. A null default
	# attack leaves the production Goblin brain intact while preventing any
	# windup, contact payload, or GameState damage route inside this scene.
	brain.set("default_attack", null)
	brain.set("attack_cooldown_timer", 0.0)
	brain.set("attack_commit_timer", 0.0)
	brain.set("state", EnemyBrainScript.EnemyState.IDLE)
	brain.set("state_timer", 0.0)
	brain.set("last_action_summary", "acquiring harmless lane target")
	brain.set("zone_debug_prints", false)
	brain.set("zone_awareness_radius", 7.0)
	brain.set("zone_hesitation_timer", 0.0)
	brain.set("strafe_switch_timer", 0.0)

	enemy.velocity = Vector3.ZERO
	enemy.set_meta("personality_lab_attack_disabled", true)

	var hit_receiver: Node = enemy.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.set("disappears_when_defeated", false)
		hit_receiver.set("restores_mana_when_defeated", false)


func reset_lab(show_feedback: bool = true) -> void:
	for lane_config: Dictionary in LANE_CONFIGS:
		var enemy_path: String = str(lane_config.get("enemy_path", ""))
		var enemy: CharacterBody3D = get_node_or_null(enemy_path) as CharacterBody3D
		var stored_lane_state: Variant = initial_lane_states.get(enemy_path, {})
		if enemy != null and stored_lane_state is Dictionary:
			reset_enemy_runtime(enemy, stored_lane_state as Dictionary)

		var hazard_path: String = str(lane_config.get("hazard_path", ""))
		var hazard: Node3D = get_node_or_null(hazard_path) as Node3D
		var stored_hazard_state: Variant = initial_hazard_states.get(hazard_path, {})
		if hazard != null and stored_hazard_state is Dictionary:
			reset_hazard_runtime(hazard, stored_hazard_state as Dictionary)

	configure_lanes()
	refresh_lab_huds()
	lab_reset.emit()

	if show_feedback:
		show_message("Enemy Personality Lab reset: all four movement lanes restored.")


func reset_enemy_runtime(enemy: CharacterBody3D, initial_state: Dictionary) -> void:
	enemy.transform = initial_state.get("transform", enemy.transform)
	enemy.visible = bool(initial_state.get("visible", true))
	enemy.velocity = Vector3.ZERO

	var brain: Node = enemy.get_node_or_null("EnemyBrain")
	if brain != null and brain.has_method("cancel_current_action"):
		brain.call("cancel_current_action", "personality lab reset")

	var hit_receiver: Node = enemy.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.set("current_health", int(hit_receiver.get("max_health")))
		hit_receiver.set("current_stance", int(hit_receiver.get("max_stance")))

	var status_receiver: Node = enemy.get_node_or_null("StatusReceiver")
	if status_receiver != null and status_receiver.has_method("clear_all_statuses"):
		status_receiver.call("clear_all_statuses")

	var force_receiver: Node = enemy.get_node_or_null("ForceReceiver")
	if force_receiver != null:
		force_receiver.set("external_velocity", Vector3.ZERO)

	var telegraph: Node = enemy.get_node_or_null("EnemyTelegraph")
	if telegraph != null and telegraph.has_method("reset"):
		telegraph.call("reset")


func reset_hazard_runtime(hazard: Node3D, initial_state: Dictionary) -> void:
	hazard.transform = initial_state.get("transform", hazard.transform)
	hazard.visible = bool(initial_state.get("visible", true))
	hazard.set("radius", float(initial_state.get("radius", hazard.get("radius"))))
	hazard.set("lifetime", float(initial_state.get("lifetime", hazard.get("lifetime"))))
	hazard.set("lifetime_timer", float(hazard.get("lifetime")))
	hazard.set("tick_timer", 0.0)
	hazard.set("spread_count", 0)
	hazard.set("has_ignited", false)

	if hazard.has_method("configure_area"):
		hazard.call("configure_area")
	if hazard.has_method("configure_visual"):
		hazard.call("configure_visual")


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
