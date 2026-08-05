extends Node

const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn")
const PersonalityTraits = preload("res://scripts/enemies/enemy_personality_traits.gd")
const EnemyBrainScript = preload("res://scripts/enemies/enemy_brain.gd")

const INITIAL_ACTIVATION_FRAMES: int = 8
const OBSERVATION_FRAMES: int = 72
const RESET_OBSERVATION_FRAMES: int = 30
const MINIMUM_TRAVEL_DISTANCE: float = 0.5
const MINIMUM_RESET_TRAVEL_DISTANCE: float = 0.15
const RESET_POSITION_TOLERANCE: float = 0.025

const EXPECTED_LANES: Array[Dictionary] = [
	{
		"enemy": "CautiousGoblin",
		"profile": "cautious",
		"target": "personality_lab_cautious_target",
		"hazard": "CautiousPoison",
	},
	{
		"enemy": "BoldGoblin",
		"profile": "bold",
		"target": "personality_lab_bold_target",
		"hazard": "BoldPoison",
	},
	{
		"enemy": "SkittishGoblin",
		"profile": "skittish",
		"target": "personality_lab_skittish_target",
		"hazard": "SkittishPoison",
	},
	{
		"enemy": "BruteGoblin",
		"profile": "brute",
		"target": "personality_lab_brute_target",
		"hazard": "BrutePoison",
	},
]

var failures: Array[String] = []


func _ready() -> void:
	var starting_health: int = GameState.get_stat("health")
	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("Enemy Personality Laboratory scene must instantiate")
		finish()
		return

	add_child(lab)

	# Capture the authored entry transforms before the first physics tick. The
	# controller has already assigned targets, but no Goblin has moved yet.
	var starting_positions: Dictionary = capture_positions(lab)
	validate_configuration(lab)

	await observe_no_attack(lab, INITIAL_ACTIVATION_FRAMES, "activation ")
	validate_activation(lab)

	var health_before_observation: int = GameState.get_stat("health")
	await observe_no_attack(lab, OBSERVATION_FRAMES, "movement ")
	validate_movement(
		lab,
		starting_positions,
		MINIMUM_TRAVEL_DISTANCE,
		""
	)
	validate_grace_health(health_before_observation, "unattended run")

	if not lab.has_method("reset_lab"):
		failures.append("Laboratory controller must expose reset_lab()")
	else:
		lab.call("reset_lab", false)
		validate_reset(lab, starting_positions)

		var reset_positions: Dictionary = capture_positions(lab)
		var health_before_reset_run: int = GameState.get_stat("health")
		await observe_no_attack(
			lab,
			RESET_OBSERVATION_FRAMES,
			"post-reset "
		)
		validate_movement(
			lab,
			reset_positions,
			MINIMUM_RESET_TRAVEL_DISTANCE,
			"post-reset "
		)
		validate_grace_health(health_before_reset_run, "post-reset run")

	lab.queue_free()
	await get_tree().process_frame

	# A failure must not leak damaged test state into another registered scene.
	if GameState.get_stat("health") != starting_health:
		GameState.set_stat("health", starting_health)

	finish()


func validate_configuration(lab: Node) -> void:
	var reference_target_distance: float = -1.0
	var reference_hazard_offset: Vector3 = Vector3.ZERO
	var reference_hazard_radius: float = -1.0
	var has_reference_geometry: bool = false

	for expected: Dictionary in EXPECTED_LANES:
		var enemy_name: String = str(expected["enemy"])
		var enemy: CharacterBody3D = get_enemy(lab, enemy_name)
		if enemy == null:
			failures.append(enemy_name + " lane enemy is missing")
			continue

		if not enemy.scene_file_path.ends_with("goblin_drone.tscn"):
			failures.append(enemy_name + " must use the shared Goblin scene")
		if not bool(enemy.get_meta("personality_lab_attack_disabled", false)):
			failures.append(enemy_name + " is missing the lab attack-disabled marker")

		var brain: Node = get_brain(enemy, enemy_name)
		if brain == null:
			continue

		var expected_profile: String = str(expected["profile"])
		var profile_id: String = str(brain.get("personality_id"))
		if profile_id != expected_profile:
			failures.append(
				enemy_name + " expected " + expected_profile + " but found " + profile_id
			)
		if PersonalityTraits.normalize_profile_id(profile_id) != expected_profile:
			failures.append(enemy_name + " does not use a registered personality profile")

		var target_group: String = str(expected["target"])
		var target: Node3D = get_tree().get_first_node_in_group(target_group) as Node3D
		if target == null:
			failures.append(enemy_name + " harmless lane target is missing")
			continue
		if str(brain.get("player_group")) != target_group:
			failures.append(enemy_name + " has the wrong lane target group")
		if brain.get("player") != target:
			failures.append(enemy_name + " did not resolve its own harmless lane target")
		if target.get_script() != null:
			failures.append(enemy_name + " target must remain inert")

		if brain.get("default_attack") != null:
			failures.append(enemy_name + " still has an armed default attack")
		if is_attack_active(brain):
			failures.append(enemy_name + " began an attack during initialization")

		var definition: Resource = brain.call("get_definition") as Resource
		if definition == null or not definition.has_method("get_detection_radius"):
			failures.append(enemy_name + " cannot report its detection radius")
			continue
		var target_distance: float = enemy.global_position.distance_to(target.global_position)
		var detection_radius: float = float(definition.call("get_detection_radius"))
		if target_distance > detection_radius:
			failures.append(
				enemy_name
				+ " target starts outside detection range ("
				+ str(snappedf(target_distance, 0.01))
				+ " > "
				+ str(snappedf(detection_radius, 0.01))
				+ ")"
			)

		var hazard_name: String = str(expected["hazard"])
		var hazard: Node3D = lab.get_node_or_null("Hazards/" + hazard_name) as Node3D
		if hazard == null:
			failures.append(enemy_name + " lane hazard is missing")
			continue
		var hazard_offset: Vector3 = hazard.global_position - enemy.global_position
		var hazard_radius: float = float(hazard.get("radius"))

		if not has_reference_geometry:
			reference_target_distance = target_distance
			reference_hazard_offset = hazard_offset
			reference_hazard_radius = hazard_radius
			has_reference_geometry = true
		else:
			if not is_equal_approx(target_distance, reference_target_distance):
				failures.append(enemy_name + " does not share the same target distance")
			if hazard_offset.distance_to(reference_hazard_offset) > 0.01:
				failures.append(enemy_name + " does not share the same hazard offset")
			if not is_equal_approx(hazard_radius, reference_hazard_radius):
				failures.append(enemy_name + " does not share the same hazard radius")


func validate_activation(lab: Node) -> void:
	for expected: Dictionary in EXPECTED_LANES:
		var enemy_name: String = str(expected["enemy"])
		var enemy: CharacterBody3D = get_enemy(lab, enemy_name)
		if enemy == null:
			continue
		var brain: Node = get_brain(enemy, enemy_name)
		if brain == null:
			continue
		if int(brain.get("state")) == EnemyBrainScript.EnemyState.IDLE:
			failures.append(enemy_name + " remained IDLE after the activation window")
		validate_target_assignment(brain, expected, enemy_name, "activation ")


func validate_movement(
	lab: Node,
	starting_positions: Dictionary,
	minimum_distance: float,
	prefix: String
) -> void:
	for expected: Dictionary in EXPECTED_LANES:
		var enemy_name: String = str(expected["enemy"])
		var enemy: CharacterBody3D = get_enemy(lab, enemy_name)
		if enemy == null or not starting_positions.has(enemy_name):
			continue
		var start_position: Vector3 = starting_positions[enemy_name]
		var distance_travelled: float = start_position.distance_to(enemy.global_position)
		if distance_travelled < minimum_distance:
			failures.append(
				prefix
				+ enemy_name
				+ " moved only "
				+ str(snappedf(distance_travelled, 0.01))
				+ "m"
			)

		var brain: Node = get_brain(enemy, enemy_name)
		if brain != null:
			if int(brain.get("state")) == EnemyBrainScript.EnemyState.IDLE:
				failures.append(prefix + enemy_name + " returned to IDLE before reaching its target")
			validate_target_assignment(brain, expected, enemy_name, prefix)
			if is_attack_active(brain):
				failures.append(prefix + enemy_name + " has an active attack")


func validate_reset(lab: Node, starting_positions: Dictionary) -> void:
	for expected: Dictionary in EXPECTED_LANES:
		var enemy_name: String = str(expected["enemy"])
		var enemy: CharacterBody3D = get_enemy(lab, enemy_name)
		if enemy == null or not starting_positions.has(enemy_name):
			continue

		var start_position: Vector3 = starting_positions[enemy_name]
		if enemy.global_position.distance_to(start_position) > RESET_POSITION_TOLERANCE:
			failures.append(enemy_name + " reset did not restore its exact start")
		if enemy.velocity.length() > 0.01:
			failures.append(enemy_name + " retained velocity after reset")

		var brain: Node = get_brain(enemy, enemy_name)
		if brain != null:
			if int(brain.get("state")) != EnemyBrainScript.EnemyState.IDLE:
				failures.append(enemy_name + " reset state must begin at IDLE")
			validate_target_assignment(brain, expected, enemy_name, "reset ")
			if brain.get("default_attack") != null or is_attack_active(brain):
				failures.append(enemy_name + " reset re-armed combat")

		var hit_receiver: Node = enemy.get_node_or_null("HitReceiver")
		if hit_receiver != null:
			if int(hit_receiver.get("current_health")) != int(hit_receiver.get("max_health")):
				failures.append(enemy_name + " health was not restored by reset")
			if int(hit_receiver.get("current_stance")) != int(hit_receiver.get("max_stance")):
				failures.append(enemy_name + " stance was not restored by reset")

		var status_receiver: Node = enemy.get_node_or_null("StatusReceiver")
		if status_receiver != null and status_receiver.has_method("get_active_status_names"):
			var statuses: Array = status_receiver.call("get_active_status_names")
			if not statuses.is_empty():
				failures.append(enemy_name + " retained statuses after reset")

		var hazard_name: String = str(expected["hazard"])
		var hazard: Node = lab.get_node_or_null("Hazards/" + hazard_name)
		if hazard != null:
			if bool(hazard.get("has_ignited")):
				failures.append(hazard_name + " remained ignited after reset")
			if int(hazard.get("spread_count")) != 0:
				failures.append(hazard_name + " retained spread state after reset")
			if not is_equal_approx(
				float(hazard.get("lifetime_timer")),
				float(hazard.get("lifetime"))
			):
				failures.append(hazard_name + " lifetime was not restored by reset")


func observe_no_attack(lab: Node, frame_count: int, prefix: String) -> void:
	var reported: Dictionary = {}
	for _frame_index: int in range(frame_count):
		await get_tree().physics_frame
		for expected: Dictionary in EXPECTED_LANES:
			var enemy_name: String = str(expected["enemy"])
			if reported.has(enemy_name):
				continue
			var enemy: CharacterBody3D = get_enemy(lab, enemy_name)
			if enemy == null:
				continue
			var brain: Node = enemy.get_node_or_null("EnemyBrain")
			if brain != null and is_attack_active(brain):
				reported[enemy_name] = true
				failures.append(prefix + enemy_name + " started an attack action")


func is_attack_active(brain: Node) -> bool:
	if brain == null:
		return false
	var state: int = int(brain.get("state"))
	if (
		state == EnemyBrainScript.EnemyState.ATTACK_WINDUP
		or state == EnemyBrainScript.EnemyState.ATTACK_RECOVER
	):
		return true
	var runner_value: Variant = brain.get("action_runner")
	if runner_value is Node:
		var runner: Node = runner_value as Node
		if runner.has_method("is_running") and bool(runner.call("is_running")):
			return true
	return false


func validate_target_assignment(
	brain: Node,
	expected: Dictionary,
	enemy_name: String,
	prefix: String
) -> void:
	var target_group: String = str(expected["target"])
	var target: Node = get_tree().get_first_node_in_group(target_group)
	if target == null:
		failures.append(prefix + enemy_name + " target disappeared")
		return
	if str(brain.get("player_group")) != target_group:
		failures.append(prefix + enemy_name + " target group changed")
	if brain.get("player") != target:
		failures.append(prefix + enemy_name + " resolved a target outside its lane")


func capture_positions(lab: Node) -> Dictionary:
	var positions: Dictionary = {}
	for expected: Dictionary in EXPECTED_LANES:
		var enemy_name: String = str(expected["enemy"])
		var enemy: CharacterBody3D = get_enemy(lab, enemy_name)
		if enemy != null:
			positions[enemy_name] = enemy.global_position
	return positions


func get_enemy(lab: Node, enemy_name: String) -> CharacterBody3D:
	return lab.get_node_or_null("Lanes/" + enemy_name) as CharacterBody3D


func get_brain(enemy: CharacterBody3D, enemy_name: String) -> Node:
	var brain: Node = enemy.get_node_or_null("EnemyBrain")
	if brain == null:
		failures.append(enemy_name + " EnemyBrain is missing")
	return brain


func validate_grace_health(expected_health: int, context: String) -> void:
	var current_health: int = GameState.get_stat("health")
	if current_health != expected_health:
		failures.append(
			"Grace health changed during "
			+ context
			+ " ("
			+ str(expected_health)
			+ " -> "
			+ str(current_health)
			+ ")"
		)


func finish() -> void:
	if failures.is_empty():
		print("ENEMY_PERSONALITY_LAB_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ENEMY_PERSONALITY_LAB_SMOKE_TEST: " + failure)
	get_tree().quit(1)
