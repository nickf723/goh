extends Node

const TrainingYardScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn"
)
const ObservationAccess = preload(
	"res://scripts/animals/creature_observation_access.gd"
)
const BackstepAction: Resource = preload(
	"res://data/enemy_defenses/gremlin_backstep_defense.tres"
)
const PounceAction: Resource = preload(
	"res://data/enemy_attacks/gremlin_pounce_attack.tres"
)

var failures: Array[String] = []
var species_knowledge: Node = null
var observation_service: Node = null
var original_snapshot: Dictionary = {}
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	species_knowledge = get_node_or_null("/root/SpeciesKnowledge")
	_expect(species_knowledge != null, "SpeciesKnowledge autoload resolves")
	if species_knowledge == null:
		_finish()
		return
	original_snapshot = species_knowledge.call("get_snapshot") as Dictionary
	original_stats = GameState.get_stat_snapshot()
	species_knowledge.call("reset_species", "gremlin")
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)

	observation_service = ObservationAccess.get_service(get_tree())
	_expect(observation_service != null, "Creature observation service resolves lazily")
	if observation_service == null:
		_restore_state()
		_finish()
		return
	observation_service.call("clear_runtime_state")
	observation_service.set("sight_range", 100.0)
	observation_service.set("minimum_camera_dot", -1.0)

	await _test_live_observation_paths()
	_restore_state()
	_finish()


func _test_live_observation_paths() -> void:
	var yard_value: Variant = TrainingYardScene.instantiate()
	_expect(yard_value is Node3D, "Familiar Training Yard instantiates")
	if not yard_value is Node3D:
		return
	var yard: Node3D = yard_value as Node3D
	yard.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(yard)
	await get_tree().process_frame
	await get_tree().process_frame

	var player: Node3D = yard.get_node_or_null("Player") as Node3D
	var enemy_root: Node = yard.get_node_or_null("EnemyRoot")
	_expect(player != null and enemy_root != null, "Training Yard resolves player and Gremlins")
	if player == null or enemy_root == null or enemy_root.get_child_count() < 2:
		yard.queue_free()
		return
	var first: Node3D = enemy_root.get_child(0) as Node3D
	var second: Node3D = enemy_root.get_child(1) as Node3D
	_expect(first != null and second != null, "Two wild Gremlins resolve")
	if first == null or second == null:
		yard.queue_free()
		return

	_expect(first.is_in_group("creature_observable"), "Gremlin joins observable creature group")
	_expect(str(first.get_meta("creature_species_id", "")) == "gremlin", "Gremlin publishes species identity")
	var brain: Node = first.get_node_or_null("EnemyBrain")
	_expect(brain != null, "Observation-aware Gremlin brain resolves")
	if brain != null:
		var brain_script: Script = brain.get_script() as Script
		_expect(
			brain_script != null
			and brain_script.resource_path == "res://scripts/enemies/gremlin_observation_brain.gd",
			"Gremlin uses observation-aware brain layer"
		)

	_point_camera_at(player, first)
	observation_service.call("_scan_for_first_sightings")
	await get_tree().process_frame
	_expect(_has_discovery("first_encounter"), "Seeing a Gremlin records First Encounter")

	if brain != null:
		brain.call("on_action_active_started", BackstepAction)
	_expect(_has_discovery("witnessed_backstep"), "Backstep active phase records witnessed technique")

	if brain != null:
		brain.set("player", player)
		brain.call("on_action_completed", PounceAction)
	_expect(_has_discovery("survived_pounce"), "Completing Pounce against living Grace records survival")

	observation_service.call(
		"report_squad_coordination",
		first,
		[{"granted": true, "kind": "melee_lane"}],
		{"squad_id": "familiar_training_wild"}
	)
	_expect(_has_discovery("pack_coordination"), "Two-member tactical coordination records pack behavior")

	var payload_receiver: Node = first.get_node_or_null("PayloadReceiver")
	_expect(payload_receiver != null, "Gremlin observation payload receiver resolves")
	if payload_receiver != null:
		var wet_payload := DamagePayload.new()
		wet_payload.amount = 0
		wet_payload.stance_damage = 0
		wet_payload.element = "water"
		wet_payload.source_name = "Observation Wet"
		wet_payload.hit_type = "test"
		wet_payload.status_effect = "wet"
		wet_payload.status_duration = 5.0
		wet_payload.status_strength = 1.0
		wet_payload.tags = ["water", "wet", "magic"]
		payload_receiver.call("receive_payload", wet_payload)

		var lightning_payload := DamagePayload.new()
		lightning_payload.amount = 0
		lightning_payload.stance_damage = 0
		lightning_payload.element = "lightning"
		lightning_payload.source_name = "Observation Lightning"
		lightning_payload.hit_type = "test"
		lightning_payload.tags = ["lightning", "magic"]
		payload_receiver.call("receive_payload", lightning_payload)
	_expect(_has_discovery("conduct_susceptibility"), "Wet Conduction records elemental susceptibility")

	var points_before_duplicate: int = _get_points()
	brain.call("on_action_active_started", BackstepAction)
	_expect(_get_points() == points_before_duplicate, "Duplicate observations do not farm knowledge")

	first.call("begin_defeat_cleanup")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(not _has_discovery("defeated_wild_pack"), "One defeated member does not count as a defeated pack")

	second.call("begin_defeat_cleanup")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(_has_discovery("defeated_wild_pack"), "Final pack defeat records the battle insight")

	var data: Dictionary = _species_data()
	_expect(int(data.get("points", 0)) == 10, "Six live observations award the authored ten knowledge points")
	_expect(int(data.get("rank", 0)) >= 3, "Live field study reaches Gremlin Bonded rank")
	var service_debug_value: Variant = observation_service.call("get_debug_data")
	var service_debug: Dictionary = service_debug_value as Dictionary if service_debug_value is Dictionary else {}
	_expect(int(service_debug.get("events_reported", 0)) >= 7, "Observation service records event history")
	_expect(int(service_debug.get("discoveries_awarded", 0)) == 6, "Observation service awards six unique discoveries")

	yard.queue_free()
	await get_tree().process_frame


func _point_camera_at(player: Node3D, target: Node3D) -> void:
	var camera: Camera3D = player.get_viewport().get_camera_3d()
	if camera == null:
		return
	camera.global_position = player.global_position + Vector3(0.0, 2.0, 1.5)
	camera.look_at(target.global_position + Vector3.UP * 0.7, Vector3.UP)


func _species_data() -> Dictionary:
	var value: Variant = species_knowledge.call("get_species_data", "gremlin")
	return value as Dictionary if value is Dictionary else {}


func _has_discovery(discovery_id: String) -> bool:
	var data: Dictionary = _species_data()
	var discoveries_value: Variant = data.get("discoveries", {})
	return (
		discoveries_value is Dictionary
		and (discoveries_value as Dictionary).has(discovery_id)
	)


func _get_points() -> int:
	return int(_species_data().get("points", 0))


func _restore_state() -> void:
	if observation_service != null:
		observation_service.call("clear_runtime_state")
	if species_knowledge != null and not original_snapshot.is_empty():
		species_knowledge.call("apply_snapshot", original_snapshot)
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("CREATURE_OBSERVATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CREATURE_OBSERVATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
