extends Node

const VillageScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_ruined_village_approach_v1.tscn")
const EncounterData: EncounterDefinition = preload("res://data/encounters/village_square_ambush.tres")
const OutdoorRemasterFixture = preload("res://scripts/tests/ruined_village_outdoor_remaster_test_fixture.gd")

var failures: Array[String] = []
var village: Node


func _ready() -> void:
	GameState.reset_run()
	village = VillageScene.instantiate()
	add_child(village)

	for _index: int in range(14):
		await get_tree().process_frame
	await get_tree().physics_frame

	validate_level_structure()
	validate_adventure_slice_graph()
	await validate_adventure_slice_progression()
	validate_outdoor_remaster()
	validate_encounter_definition()
	validate_two_solution_gate()
	await validate_water_ice_bridge()
	validate_sound_memory()
	await validate_save_state_sync()
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
	if geometry == null or geometry.get_child_count() < 34:
		failures.append("procedural support terrain and traversal ramps did not build the expected density")

	if get_tree().get_nodes_in_group("ruined_village_traversal_ready").size() != 1:
		failures.append("traversal grading did not finish")

	if get_tree().get_nodes_in_group("ruined_village_save_sync").size() != 1:
		failures.append("save-state world synchronizer is missing")

	if get_tree().get_nodes_in_group("village_clue").size() < 3:
		failures.append("level must expose at least three environmental clues")

	if get_tree().get_nodes_in_group("encounter_controller").size() != 1:
		failures.append("level must contain exactly one local encounter controller")

	var player: Node3D = village.get_node_or_null("Player") as Node3D
	if player != null and abs(player.rotation_degrees.y) > 0.01:
		failures.append("Grace must face down the village route on entry")


func validate_adventure_slice_graph() -> void:
	var slice_director: Node = village.get_node_or_null("AdventureSliceDirector")
	if slice_director == null:
		failures.append("first production adventure slice director is missing")
		return
	if not bool(slice_director.get_meta("production_slice_active", false)):
		failures.append("production slice director did not activate on the canonical village scene")
	if str(village.get_meta("first_production_adventure_slice", "")) != "v1":
		failures.append("village root does not publish the first production slice contract")
	if not bool(village.get_meta("showcase_shortcuts_suppressed", false)):
		failures.append("canonical village still ran laboratory showcase startup shortcuts")

	var chunks_root: Node = village.get_node_or_null("AdventureChunks")
	if chunks_root == null or chunks_root.get_child_count() != 5:
		failures.append("production slice must assemble five authored adventure chunks")

	var sequence: Node = village.get_node_or_null("FirstProductionAdventureSequence")
	if sequence == null or not sequence.has_method("get_graph_snapshot"):
		failures.append("production slice adventure sequence is missing")
		return
	var snapshot: Dictionary = sequence.call("get_graph_snapshot") as Dictionary
	if str(snapshot.get("sequence_id", "")) != "first_production_adventure_slice_v1":
		failures.append("production sequence id changed unexpectedly")
	if not (snapshot.get("validation_errors", []) as Array).is_empty():
		failures.append("production slice adventure graph has validation errors")
	var chunks: Dictionary = snapshot.get("chunks", {}) as Dictionary
	if chunks.size() != 5:
		failures.append("production slice graph must expose five chunk definitions")
	var active_chunks: Array = snapshot.get("active_chunks", []) as Array
	if not active_chunks.has("ruined_village_investigation"):
		failures.append("investigation chunk should be the active opening beat")

	var investigation: Dictionary = chunks.get("ruined_village_investigation", {}) as Dictionary
	if int(investigation.get("required_count", 0)) != 3:
		failures.append("investigation beat must require all three environmental clues")
	var combat: Dictionary = chunks.get("ruined_village_square_combat", {}) as Dictionary
	if not (combat.get("dependencies", []) as Array).has("ruined_village_investigation"):
		failures.append("village combat must depend on investigation")
	var ravine: Dictionary = chunks.get("ruined_village_ravine_choice", {}) as Dictionary
	if not (ravine.get("dependencies", []) as Array).has("ruined_village_square_combat"):
		failures.append("ravine choice must depend on square combat")
	var memory: Dictionary = chunks.get("ruined_village_sound_memory", {}) as Dictionary
	if not bool(memory.get("optional", false)):
		failures.append("Sound memory must remain optional")
	var threshold: Dictionary = chunks.get("ruined_village_church_threshold", {}) as Dictionary
	if not (threshold.get("dependencies", []) as Array).has("ruined_village_ravine_choice"):
		failures.append("church threshold must depend on a solved ravine route")

	for clue: Node in get_tree().get_nodes_in_group("village_clue"):
		if village.is_ancestor_of(clue) and not clue.has_signal("clue_inspected"):
			failures.append("village clues must expose clue_inspected for authored sequencing")
			break
	var debris_gate: Node = village.get_node_or_null("VillagePuzzles/RavineDebrisGate")
	if debris_gate != null and not debris_gate.has_signal("gate_opened"):
		failures.append("ravine debris gate must expose gate_opened for authored sequencing")
	var bridges: Array[Node] = get_tree().get_nodes_in_group("village_ice_bridge")
	if not bridges.is_empty() and not bridges[0].has_signal("bridge_frozen"):
		failures.append("ice bridge must expose bridge_frozen for authored sequencing")
	var memories: Array[Node] = get_tree().get_nodes_in_group("village_memory")
	if not memories.is_empty() and not memories[0].has_signal("memory_found"):
		failures.append("Sound memory must expose memory_found for optional sequencing")

	var player: Node = village.get_node_or_null("Player")
	if player != null:
		var caster: Node = player.get_node_or_null("AbilityCaster")
		if caster != null and int(caster.get("current_ability_index")) != 0:
			failures.append("production slice should start on the first shared spell instead of auto-selecting Flight")
		var aerial: Node = player.get_node_or_null("AerialLocomotion")
		if aerial != null and bool(aerial.get("flight_unlocked")):
			failures.append("production slice must not auto-unlock Flight and bypass the ravine")


func validate_adventure_slice_progression() -> void:
	var sequence: Node = village.get_node_or_null("FirstProductionAdventureSequence")
	if sequence == null or not sequence.has_method("get_graph_snapshot"):
		return

	for clue_id: String in ["arrival_crater", "lifted_foundation", "empty_hearth"]:
		var clue: Node = find_clue_by_id(clue_id)
		if clue == null:
			failures.append("production progression could not resolve clue " + clue_id)
			return
		clue.call("interact")
	await get_tree().process_frame

	var snapshot: Dictionary = sequence.call("get_graph_snapshot") as Dictionary
	var completed: Array = snapshot.get("completed_chunks", []) as Array
	var active: Array = snapshot.get("active_chunks", []) as Array
	if not completed.has("ruined_village_investigation"):
		failures.append("three clue inspections did not complete the investigation chunk")
	if not active.has("ruined_village_square_combat"):
		failures.append("investigation completion did not activate village-square combat")
	if not active.has("ruined_village_sound_memory"):
		failures.append("investigation completion did not activate the optional Sound memory")

	var objective_before_memory: String = GameState.current_objective
	var memories: Array[Node] = get_tree().get_nodes_in_group("village_memory")
	if not memories.is_empty():
		var memory: Node = memories[0]
		var revealable: Node = memory.get_node_or_null("RevealableReceiver")
		if revealable != null and revealable.has_method("receive_detection"):
			var detection := DetectionPayload.new()
			detection.source_name = "Adventure Slice Progression Test"
			detection.detection_type = "resonance"
			detection.tags = ["sound", "reveal"]
			detection.reveal_duration = 30.0
			revealable.call("receive_detection", detection)
			memory.call("interact")
	await get_tree().process_frame

	snapshot = sequence.call("get_graph_snapshot") as Dictionary
	completed = snapshot.get("completed_chunks", []) as Array
	if not completed.has("ruined_village_sound_memory"):
		failures.append("revealed wooden-bird interaction did not complete the optional memory chunk")
	if GameState.current_objective != objective_before_memory:
		failures.append("optional Sound memory hijacked the active main-route objective")

	var encounter: Node = village.get_node_or_null("VillageEncounters/VillageSquareEncounter")
	if encounter == null:
		failures.append("production progression could not resolve village encounter")
		return
	encounter.call("complete_encounter")
	await get_tree().process_frame

	snapshot = sequence.call("get_graph_snapshot") as Dictionary
	completed = snapshot.get("completed_chunks", []) as Array
	active = snapshot.get("active_chunks", []) as Array
	if not completed.has("ruined_village_square_combat"):
		failures.append("existing encounter lifecycle did not complete the combat chunk")
	if not active.has("ruined_village_ravine_choice"):
		failures.append("combat completion did not activate the ravine choice")

	var debris_gate: Node = village.get_node_or_null("VillagePuzzles/RavineDebrisGate")
	if debris_gate == null:
		failures.append("production progression could not resolve ravine debris gate")
		return
	var fire_payload := DamagePayload.new()
	fire_payload.element = "fire"
	fire_payload.source_name = "Adventure Slice Progression Test"
	fire_payload.tags = ["fire", "burning"]
	debris_gate.call("receive_damage_payload", fire_payload)
	await get_tree().process_frame

	snapshot = sequence.call("get_graph_snapshot") as Dictionary
	completed = snapshot.get("completed_chunks", []) as Array
	active = snapshot.get("active_chunks", []) as Array
	if not completed.has("ruined_village_ravine_choice"):
		failures.append("one valid ravine solution did not complete the ANY-policy route chunk")
	if not active.has("ruined_village_church_threshold"):
		failures.append("ravine completion did not activate the church threshold")

	var exit: Node = village.get_node_or_null("VillageInteractions/ChurchTrialEntrance")
	if exit != null and exit.has_signal("exit_triggered"):
		exit.emit_signal("exit_triggered", {"ok": true, "test_only": true})
	await get_tree().process_frame
	snapshot = sequence.call("get_graph_snapshot") as Dictionary
	if not bool(snapshot.get("completed", false)):
		failures.append("church threshold lifecycle did not complete the production sequence")
	if not GameState.get_flag("first_production_adventure_slice_v1"):
		failures.append("completed production sequence did not persist its completion flag")

	# Return every authoritative source to its ordinary opening state before the
	# older focused interaction regressions run below.
	sequence.call("reset_sequence", true)
	var square_gate: Node = village.get_node_or_null("VillagePuzzles/SquareEncounterBarrier")
	if square_gate != null and square_gate.has_method("reset_gate"):
		square_gate.call("reset_gate")
	await get_tree().process_frame


func validate_outdoor_remaster() -> void:
	var raw_failures: Array[String] = OutdoorRemasterFixture.run(village)
	for failure: String in raw_failures:
		failures.append(failure)


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
	var payload_target: Area3D = bridge.get_node_or_null("PayloadTarget") as Area3D
	if payload_target == null:
		failures.append("bridge target collision must be a non-solid Area3D")
		return

	var status_receiver: Node = payload_target.get_node_or_null("StatusReceiver")
	if status_receiver == null or not status_receiver.has_method("apply_status"):
		failures.append("Water/Ice bridge has no StatusReceiver")
		return

	var target_collision: CollisionShape3D = payload_target.get_node_or_null("TargetCollision") as CollisionShape3D
	if target_collision == null or target_collision.disabled:
		failures.append("bridge spell target is unavailable before freezing")

	var bridge_collision: CollisionShape3D = bridge.get_node_or_null("BridgeCollision") as CollisionShape3D
	if bridge_collision == null:
		failures.append("bridge traversal collision is missing")
		return

	if not bridge_collision.disabled:
		failures.append("bridge traversal collision starts enabled before freezing")

	status_receiver.call("apply_status", "wet", 10.0, 1.0, "Smoke Test Water")
	status_receiver.call("apply_status", "frozen", 10.0, 1.0, "Smoke Test Ice")
	await get_tree().process_frame

	if not bool(bridge.get("is_frozen_bridge")):
		failures.append("Water/Ice bridge did not become traversable after frozen status")

	if bridge_collision.disabled:
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


func validate_save_state_sync() -> void:
	var square_gate: Node = village.get_node_or_null("VillagePuzzles/SquareEncounterBarrier")
	var debris_gate: Node = village.get_node_or_null("VillagePuzzles/RavineDebrisGate")
	var bridge_nodes: Array[Node] = get_tree().get_nodes_in_group("village_ice_bridge")
	var memory_nodes: Array[Node] = get_tree().get_nodes_in_group("village_memory")
	var encounter_nodes: Array[Node] = get_tree().get_nodes_in_group("encounter_controller")
	var sync_node: Node = village.get_node_or_null("SaveWorldSync")
	var clue: Node = find_clue_by_id("arrival_crater")

	if square_gate == null or debris_gate == null or bridge_nodes.is_empty() or memory_nodes.is_empty() or encounter_nodes.is_empty() or sync_node == null or clue == null:
		failures.append("save-state synchronization fixtures are incomplete")
		return

	var bridge: Node = bridge_nodes[0]
	var memory: Node = memory_nodes[0]
	var encounter: Node = encounter_nodes[0]

	square_gate.call("reset_gate")
	debris_gate.call("reset_gate")
	bridge.call("reset_bridge")
	memory.call("reset_memory")
	clue.call("reset_clue")
	encounter.call("reset_encounter")

	GameState.set_flag("opened_square_barrier", true)
	GameState.set_flag("opened_ravine_debris", true)
	GameState.set_flag("froze_village_bridge", true)
	GameState.set_flag("found_village_memory", true)
	GameState.set_flag("inspected_arrival_crater", true)
	GameState.set_flag("cleared_village_square_ambush", true)

	sync_node.call("synchronize_world_from_game_state")
	await get_tree().process_frame
	await get_tree().physics_frame

	if not bool(square_gate.get("is_open")):
		failures.append("saved encounter barrier did not restore open")
	if not bool(debris_gate.get("is_open")):
		failures.append("saved debris route did not restore open")
	if not bool(bridge.get("is_frozen_bridge")):
		failures.append("saved ice bridge did not restore traversable")
	if not bool(memory.call("is_revealed")):
		failures.append("saved Sound memory did not restore revealed")
	if not bool(clue.get("has_been_read")):
		failures.append("saved arrival clue did not restore read state")
	if not bool(encounter.get("is_complete")):
		failures.append("saved encounter did not restore complete")


func find_clue_by_id(required_id: String) -> Node:
	for clue: Node in get_tree().get_nodes_in_group("village_clue"):
		if str(clue.get("clue_id")) == required_id:
			return clue
	return null


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
