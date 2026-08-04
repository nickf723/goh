extends Node3D

const BondedAnimalScript = preload("res://scripts/animals/bonded_animal_actor.gd")
const LabScene = preload("res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn")
const TEST_SAVE_PATH: String = "user://animal_bonding_persistence_smoke_test.json"
const TEST_ANIMAL_ID: String = "smoke_test:memory_sheep"

var failures: Array[String] = []
var grace: CharacterBody3D
var actors: Array[BondedAnimalActor] = []
var threatening: bool = false
var store: AnimalBondStore


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_build_floor()
	store = AnimalBondStore.get_or_create(get_tree(), TEST_SAVE_PATH)
	store.clear_records("", false)
	store.save_to_disk()
	GameState.set_inventory_count("field_treat", 6)

	grace = CharacterBody3D.new()
	grace.position = Vector3(0.0, 0.5, -2.8)
	add_child(grace)

	var sheep: BondedAnimalActor = _spawn_sheep(Vector3(0.0, 0.5, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	sheep.force_decision(true)

	var treats_before: int = GameState.get_inventory_count("field_treat")
	var first_feed: Dictionary = sheep.interact_with_grace("feed")
	var second_feed: Dictionary = sheep.interact_with_grace("feed")
	var third_feed: Dictionary = sheep.interact_with_grace("feed")
	_expect(
		bool(first_feed.get("ok", false))
		and bool(second_feed.get("ok", false))
		and bool(third_feed.get("ok", false)),
		"three nearby Field Treats build the relationship"
	)
	_expect(
		GameState.get_inventory_count("field_treat") == treats_before - 3,
		"feeding consumes real inventory items"
	)
	_expect(
		bool(sheep.get_bond_requirements().get("eligible", false)),
		"three positive interactions make the named sheep bond-eligible"
	)

	var bond_result: Dictionary = sheep.attempt_bond()
	_expect(bool(bond_result.get("ok", false)), "eligible named animal can bond with Grace")
	_expect(sheep.bonded and sheep.follow_enabled, "bonding enables follow behavior")
	_expect(store.has_record(TEST_ANIMAL_ID), "bonded animal writes a named persistent record")

	grace.position = Vector3(0.0, 0.5, -6.5)
	sheep.rotation.y = 0.0
	sheep.brain.clear_cooldowns()
	sheep.brain.clear_memory()
	sheep.set_drive("hunger", 0.0)
	sheep.set_drive("fear", 0.0)
	sheep.set_drive("fatigue", 0.0)
	sheep.set_drive("social_need", 0.0)
	sheep.perception.reset()
	var follow_decision: Dictionary = sheep.force_decision(true)
	_expect(not follow_decision.is_empty(), "bonded animal still produces a utility decision")
	_expect(sheep.current_action_id == "follow_grace", "bond converts Idle into voluntary Follow Grace")
	var distance_before: float = sheep.global_position.distance_to(grace.global_position)
	for _frame: int in range(42):
		await get_tree().physics_frame
	var distance_after: float = sheep.global_position.distance_to(grace.global_position)
	_expect(distance_after < distance_before - 0.35, "bonded follow behavior physically closes distance to Grace")

	sheep.persist_named_state(true)
	var saved_trust: float = sheep.relationship.trust
	store.clear_records("", false)
	_expect(not store.has_record(TEST_ANIMAL_ID), "test can clear in-memory bond records before reload")
	_expect(store.load_from_disk(), "animal bond sidecar reloads from disk")
	_expect(store.has_record(TEST_ANIMAL_ID), "disk reload restores the named animal record")

	sheep.queue_free()
	await get_tree().process_frame
	var reloaded_sheep: BondedAnimalActor = _spawn_sheep(Vector3(2.0, 0.5, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	_expect(reloaded_sheep.bonded, "new actor instance restores bonded state by stable identity")
	_expect(reloaded_sheep.follow_enabled, "new actor instance restores follow preference")
	_expect(
		absf(reloaded_sheep.relationship.trust - saved_trust) < 0.02,
		"new actor instance restores persistent trust"
	)

	var trust_before_attack: float = reloaded_sheep.relationship.trust
	var attack_result: Dictionary = reloaded_sheep.report_grace_event("attack")
	_expect(bool(attack_result.get("ok", false)), "real gameplay harm events reach the relationship layer")
	_expect(reloaded_sheep.relationship.trust < trust_before_attack, "attacking damages persistent trust")
	_expect(reloaded_sheep.harm_events == 1, "harm history is recorded on the named animal")

	var lab_instance: Node = LabScene.instantiate()
	_expect(lab_instance is AnimalBondingLab, "playable Animal Behavior Lab uses the bonding extension")
	if lab_instance != null:
		lab_instance.queue_free()

	for actor: BondedAnimalActor in actors:
		if is_instance_valid(actor):
			actor.queue_free()
	await get_tree().process_frame
	GameState.set_inventory_count("field_treat", 0)
	store.clear_records("", true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	_finish()


func _spawn_sheep(position_value: Vector3) -> BondedAnimalActor:
	var actor := BondedAnimalScript.new() as BondedAnimalActor
	actor.animal_name = "Memory Sheep"
	actor.species_id = "sheep"
	actor.personality_profile_id = "cautious"
	actor.persistent_animal_id = TEST_ANIMAL_ID
	actor.decision_interval = 10.0
	actor.move_speed = 2.2
	actor.position = position_value
	add_child(actor)
	actors.append(actor)
	return actor


func get_animal_grace_target(_animal: GenericAnimalActor) -> Node3D:
	return grace


func get_animal_threat_target(_animal: GenericAnimalActor) -> Node3D:
	return grace


func is_grace_threatening(_animal: GenericAnimalActor) -> bool:
	return threatening


func is_animal_threat_mode_enabled(_animal: GenericAnimalActor) -> bool:
	return threatening


func get_animal_noise_position(_animal: GenericAnimalActor) -> Vector3:
	return grace.global_position if grace != null else Vector3.ZERO


func get_animal_noise_strength(_animal: GenericAnimalActor) -> float:
	return 0.0


func get_animal_forage_position(animal: GenericAnimalActor) -> Vector3:
	return animal.home_position


func get_animal_water_position(animal: GenericAnimalActor) -> Vector3:
	return animal.home_position + Vector3(4.0, 0.0, 0.0)


func broadcast_animal_alert(
	source: GenericAnimalActor,
	position_value: Vector3,
	severity: float
) -> void:
	for actor: BondedAnimalActor in actors:
		if actor == source or not is_instance_valid(actor):
			continue
		if actor.species_id == source.species_id:
			actor.receive_social_alert(position_value, severity)


func clamp_animal_position(value: Vector3) -> Vector3:
	return value


func _build_floor() -> void:
	var floor := StaticBody3D.new()
	floor.position = Vector3(0.0, -0.25, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.5, 30.0)
	collision.shape = shape
	floor.add_child(collision)
	add_child(floor)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ANIMAL_BONDING_PERSISTENCE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ANIMAL_BONDING_PERSISTENCE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
