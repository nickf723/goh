extends Node

const VillageScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn")
const EncounterData: EncounterDefinition = preload("res://data/encounters/village_square_ambush.tres")

var failures: Array[String] = []
var village: Node


func _ready() -> void:
	GameState.reset_run()
	village = VillageScene.instantiate()
	add_child(village)

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	validate_level_structure()
	validate_encounter_definition()
	validate_two_solution_gate()
	validate_water_ice_bridge()
	validate_sound_memory()
	validate_checkpoint_and_exit()

	if village != null and is_instance_valid(village):
		village.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("RUINED_VILLAGE_APPROACH_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("RUINED_VILLAGE_APPROACH_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func validate_level_structure() -> void:
	if village == null:
		failures.append("level scene failed to instantiate")
		return

	if not village.is_in_group("ruined_village_approach"):
		failures.append("level root is missing ruined_village_approach group")

	if village.get_node_or_null("Player") == null:
		failures.append("level has no Player")

	if village.get_node_or_null("GameUI") == null:
		failures.append("level has no GameUI")

	var geometry: Node = village.get_node_or_null("GeneratedGeometry")
	if geometry == null or geometry.get_child_count() < 30:
		failures.append("procedural terrain did not build the expected geometry density")

	if get_tree().get_nodes_in_group("village_clue").size() < 3:
		failures.append("level must expose at least three environmental clues")

	if get_tree().get_nodes_in_group("encounter_controller").size() != 1:
		failures.append("level must contain exactly one local encounter controller")


func validate_encounter_definition() -> void:
	if EncounterData == null:
		failures.append("village encounter resource is missing")
		return

	for error_text: String in EncounterData.validate_definition():
		failures.append("encounter definition: " + error_text)

	if EncounterData.enemy_scenes.size() != 3:
		failures.append("village square encounter should contain three enemies")

	if EncounterData.completion_flag != "cleared_village_square_ambush":
		failures.append("encounter completion flag changed unexpectedly")


func validate_two_solution_gate() -> void:
	var gate: Node = village.get_node_or_null("VillagePuzzles/RavineDebrisGate")
	if gate == null:
		failures.append("multi-solution ravine debris gate is missing")
		return

	var ice_payload: DamagePayload = DamagePayload.new()
	ice_payload.element = "ice"
	ice_payload.source_name = "Smoke Test Ice"
	ice_payload.tags = ["ice", "freeze"]
	gate.call("receive_damage_payload", ice_payload)

	if not bool(gate.get("is_frozen")):
		failures.append("ice did not prime the ravine debris gate")

	var heavy_payload: DamagePayload = DamagePayload.new()
	heavy_payload.element = "neutral"
	heavy_payload.source_name = "Smoke Test Heavy"
	heavy_payload.tags = ["weapon", "heavy", "force", "blunt"]
	heavy_payload.knockback_strength = 5.0
	gate.call("receive_damage_payload", heavy_payload)

	if not bool(gate.get("is_open")):
		failures.append("frozen debris did not open from a Heavy/force hit")

	gate.call("reset_gate")
	var fire_payload: DamagePayload = DamagePayload.new()
	fire_payload.element = "fire"
	fire_payload.source_name = "Smoke Test Fire"
	fire_payload.tags = ["fire", "burning"]
	gate.call("receive_damage_payload", fire_payload)

	if not bool(gate.get("is_open")):
		failures.append("fire did not open the alternative ravine route")


func validate_water_ice_bridge() -> void:
	var bridges: Array[Node] = get_tree().get_nodes_in_group("village_ice_bridge")
	if bridges.size() != 1:
		failures.append("level must contain exactly one Water/Ice bridge")
		return

	var bridge: Node = bridges[0]
	var status_receiver: Node = bridge.get_node_or_null("StatusReceiver")
	if status_receiver == null or not status_receiver.has_method("apply_status"):
		failures.append("Water/Ice bridge has no StatusReceiver")
		return

	status_receiver.call("apply_status", "wet", 10.0, 1.0, "Smoke Test Water")
	status_receiver.call("apply_status", "frozen", 10.0, 1.0, "Smoke Test Ice")
	await get_tree().process_frame

	if not bool(bridge.get("is_frozen_bridge")):
		failures.append("Water/Ice bridge did not become traversable after frozen status")

	var bridge_collision: CollisionShape3D = bridge.get_node_or_null("BridgeCollision") as CollisionShape3D
	if bridge_collision == null or bridge_collision.disabled:
		failures.append("frozen bridge collision remained disabled")


func validate_sound_memory() -> void:
	var memories: Array[Node] = get_tree().get_nodes_in_group("village_memory")
	if memories.size() != 1:
		failures.append("level must contain exactly one optional Sound memory")
		return

	var memory: Node = memories[0]
	var revealable: Node = memory.get_node_or_null("RevealableReceiver")
	if revealable == null or not revealable.has_method("receive_detection"):
		failures.append("Sound memory has no RevealableReceiver")
		return

	var detection: DetectionPayload = DetectionPayload.new()
	detection.source_name = "Smoke Test Sound"
	detection.detection_type = "resonance"
	detection.tags = ["sound", "reveal"]
	detection.reveal_duration = 30.0
	revealable.call("receive_detection", detection)

	if not bool(revealable.get("is_revealed")):
		failures.append("Sound detection did not reveal the optional memory")


func validate_checkpoint_and_exit() -> void:
	if get_tree().get_nodes_in_group("save_point").is_empty():
		failures.append("church grounds checkpoint is missing")

	var exit: Node = village.get_node_or_null("VillageInteractions/ChurchTrialEntrance")
	if exit == null:
		failures.append("Church Trial entrance is missing")
		return

	if str(exit.get("next_scene_path")) != "res://scenes/levels/prototypes/prototype_boss_dungeon_chain_v1.tscn":
		failures.append("Church Trial entrance points to the wrong scene")

	if bool(exit.get("triggers_on_touch")):
		failures.append("Church Trial entrance should require deliberate interaction")
