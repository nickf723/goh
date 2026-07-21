extends Node

const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_enemy_personality_lab_v1.tscn")
const EnemyBrainScript = preload("res://scripts/enemies/enemy_brain.gd")

var failures: Array[String] = []
var original_health: int = 0


func _ready() -> void:
	original_health = GameState.get_stat("health")
	var controlled_health: int = max(original_health, 7)
	GameState.set_stat("health", controlled_health)

	var lab: Node3D = LabScene.instantiate() as Node3D
	add_child.call_deferred(lab)
	await get_tree().process_frame
	await get_tree().physics_frame

	var records: Array[Dictionary] = lab.call("get_lane_records")
	assert_equal(records.size(), 4, "configured lane count")
	var opening_positions: Array[Vector3] = []
	var baseline_target_distance: float = -1.0
	for lane_index: int in records.size():
		var record: Dictionary = records[lane_index]
		var goblin: CharacterBody3D = record["goblin"] as CharacterBody3D
		var brain: Node = record["brain"] as Node
		var target: Node3D = record["target"] as Node3D
		var target_distance: float = goblin.global_position.distance_to(target.global_position)
		var opening_transform: Transform3D = record["goblin_transform"] as Transform3D
		opening_positions.append(opening_transform.origin)
		assert_true(brain.get("player") == target, "lane %d resolves its own target" % (lane_index + 1))
		assert_true(brain.get("player") != lab.get_node("Player"), "lane %d does not target Grace" % (lane_index + 1))
		assert_true(brain.call("get_current_attack") == null, "lane %d has no attack action" % (lane_index + 1))
		assert_true(target_distance <= float(brain.call("get_definition").get_detection_radius()), "lane %d target begins within detection" % (lane_index + 1))
		if baseline_target_distance < 0.0:
			baseline_target_distance = target_distance
		else:
			assert_approx(target_distance, baseline_target_distance, 0.001, "lane %d start distance matches" % (lane_index + 1))

	var attack_state_observed: Array[bool] = [false, false, false, false]
	for _physics_step: int in 90:
		await get_tree().physics_frame
		for lane_index: int in records.size():
			var brain: Node = records[lane_index]["brain"] as Node
			var state: int = int(brain.get("state"))
			if state == EnemyBrainScript.EnemyState.ATTACK_WINDUP or state == EnemyBrainScript.EnemyState.ATTACK_RECOVER:
				attack_state_observed[lane_index] = true

	for lane_index: int in records.size():
		var record: Dictionary = records[lane_index]
		var goblin: CharacterBody3D = record["goblin"] as CharacterBody3D
		var brain: Node = record["brain"] as Node
		var moved_distance: float = goblin.global_position.distance_to(opening_positions[lane_index])
		assert_true(moved_distance >= 1.0, "lane %d moves a meaningful distance" % (lane_index + 1))
		assert_true(int(brain.get("state")) != EnemyBrainScript.EnemyState.IDLE, "lane %d leaves IDLE" % (lane_index + 1))
		assert_true(not attack_state_observed[lane_index], "lane %d never starts an attack" % (lane_index + 1))

	assert_equal(GameState.get_stat("health"), controlled_health, "Grace health during unattended run")
	lab.call("reset_lab")

	for lane_index: int in records.size():
		var record: Dictionary = records[lane_index]
		var goblin: CharacterBody3D = record["goblin"] as CharacterBody3D
		var brain: Node = record["brain"] as Node
		var target: Node3D = record["target"] as Node3D
		assert_approx(goblin.global_position.distance_to(opening_positions[lane_index]), 0.0, 0.01, "lane %d reset position" % (lane_index + 1))
		assert_true(brain.get("player") == target, "lane %d reset target assignment" % (lane_index + 1))
		assert_equal(int(brain.get("state")), EnemyBrainScript.EnemyState.IDLE, "lane %d reset state" % (lane_index + 1))

	lab.queue_free()
	await get_tree().process_frame
	GameState.set_stat("health", original_health)

	if failures.is_empty():
		print("Enemy personality lab behavioral smoke test passed.")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	get_tree().quit(1)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))


func assert_true(value: bool, label: String) -> void:
	if not value:
		failures.append(label + ": expected true")


func assert_approx(actual: float, expected: float, tolerance: float, label: String) -> void:
	if abs(actual - expected) > tolerance:
		failures.append(label + ": expected " + str(expected) + " but got " + str(actual))
