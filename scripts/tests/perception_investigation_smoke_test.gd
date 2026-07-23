extends Node

const StimulusManagerScript = preload("res://scripts/perception/perception_stimulus_manager.gd")
const PerceptionLabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_perception_investigation_lab_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	await test_stimulus_contract()
	await test_laboratory_contract()
	if failures.is_empty():
		print("PERCEPTION_INVESTIGATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PERCEPTION_INVESTIGATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func test_stimulus_contract() -> void:
	var manager: PerceptionStimulusManager = StimulusManagerScript.new() as PerceptionStimulusManager
	manager.name = "PerceptionStimulusManagerTest"
	add_child(manager)
	var stimulus: PerceptionStimulus = manager.emit_stimulus(
		Vector3(3.0, 0.0, -2.0),
		10.0,
		"distraction",
		0.08,
		null,
		"Test chime",
		1.2,
		["test"]
	)
	if stimulus == null:
		failures.append("Stimulus manager must create a PerceptionStimulus")
	else:
		if stimulus.stimulus_id <= 0:
			failures.append("Stimuli require stable positive ids")
		if stimulus.category != "distraction":
			failures.append("Stimulus category must be preserved")
		if manager.get_stimuli_near(Vector3.ZERO, 5.0).size() != 1:
			failures.append("Stimulus manager must query nearby active stimuli")
	await get_tree().create_timer(0.12).timeout
	if not manager.get_active_stimuli().is_empty():
		failures.append("Expired stimuli must leave the active set")
	manager.queue_free()
	await get_tree().process_frame


func test_laboratory_contract() -> void:
	if PerceptionLabScene == null:
		failures.append("Perception laboratory scene failed to load")
		return
	var lab: Node = PerceptionLabScene.instantiate()
	if lab == null:
		failures.append("Perception laboratory scene failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var manager: Node = lab.get_node_or_null("PerceptionStimulusManager")
	var player: Node = lab.get_node_or_null("Player")
	var smoke_grid: Node = lab.get_node_or_null("PerceptionSmokeGrid")
	if manager == null or not manager.has_method("emit_stimulus"):
		failures.append("Perception laboratory requires a stimulus manager")
	if player == null or player.get_node_or_null("PerceptionMovementEmitter") == null:
		failures.append("Grace must emit movement stimuli in the laboratory")
	if smoke_grid == null or str(smoke_grid.get("gas_id")) != "smoke":
		failures.append("Perception laboratory requires a Smoke density grid")
	elif int(smoke_grid.call("get_total_cell_count")) > 600:
		failures.append("Perception Smoke grid exceeds its CPU budget")

	var sensors: Array[Node] = get_tree().get_nodes_in_group("enemy_perception_sensors")
	var visualizers: Array[Node] = get_tree().get_nodes_in_group("perception_debug_visualizers")
	if sensors.size() < 4:
		failures.append("Laboratory must contain four enemy perception sensors")
	if visualizers.size() < 4:
		failures.append("Laboratory must contain four perception debug visualizers")
	if get_tree().get_nodes_in_group("perception_emitters").size() < 9:
		failures.append("Laboratory requires footsteps, four beacons, and four breakable emitters")

	var personalities: Array[String] = []
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if not lab.is_ancestor_of(enemy):
			continue
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain == null or not brain.has_method("get_awareness_state_name"):
			continue
		personalities.append(str(brain.get("personality_id")))
		if bool(brain.get("allow_combat")):
			failures.append("Perception lab observers must not attack Grace")
	for expected: String in ["cautious", "bold", "skittish", "brute"]:
		if not personalities.has(expected):
			failures.append("Missing perception personality: " + expected)

	lab.queue_free()
	await get_tree().process_frame
