extends Node3D

const AnimalScript = preload("res://scripts/animals/generic_animal_actor.gd")

var failures: Array[String] = []
var grace: CharacterBody3D
var actors: Array[GenericAnimalActor] = []
var threatening: bool = false
var noise_position: Vector3 = Vector3.ZERO
var noise_strength: float = 0.0


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_build_floor()
	grace = CharacterBody3D.new()
	grace.position = Vector3(0.0, 0.5, -3.5)
	add_child(grace)
	var sheep: GenericAnimalActor = _spawn_animal(
		"Memory Sheep",
		"sheep",
		"cautious",
		Vector3(0.0, 0.5, 0.0)
	)
	await get_tree().process_frame
	await get_tree().physics_frame
	var first_decision: Dictionary = sheep.force_decision()
	var sight: Dictionary = sheep.get_perception_data()
	_expect(bool(sight.get("can_see_target", false)), "sheep sees Grace inside its view cone")
	_expect(bool(sight.get("remembers_target", false)), "seeing Grace creates a target memory")
	_expect(not first_decision.is_empty(), "perceived Grace still produces a valid decision")

	sheep.rotation.y = 0.0
	grace.global_position = sheep.global_position + Vector3(0.0, 0.0, 4.0)
	sheep.force_decision()
	var memory: Dictionary = sheep.get_perception_data()
	_expect(not bool(memory.get("can_see_target", true)), "sheep loses sight when Grace enters its rear blind spot")
	_expect(bool(memory.get("remembers_target", false)), "sheep retains Grace's last known position")
	_expect(float(memory.get("memory_remaining", 0.0)) > 0.0, "target memory has a visible remaining duration")

	grace.position = Vector3(0.0, 0.5, -2.8)
	sheep.perception.reset()
	sheep.force_decision()
	var feed_one: Dictionary = sheep.interact_with_grace("feed")
	var feed_two: Dictionary = sheep.interact_with_grace("feed")
	_expect(bool(feed_one.get("ok", false)) and bool(feed_two.get("ok", false)), "nearby Grace can feed an animal through the relationship API")
	_expect(float(sheep.get_relationship_data().get("trust", 0.0)) > 0.25, "repeated feeding builds persistent trust")
	_expect(sheep.get_relationship_label() == "curious", "enough trust changes the sheep relationship to Curious")

	var startle: Dictionary = sheep.interact_with_grace("startle")
	_expect(bool(startle.get("ok", false)), "Grace can startle a nearby animal")
	_expect(sheep.get_drive("fear") > 0.9, "startling spikes the animal's persistent fear drive")
	_expect(sheep.get_relationship_label() == "afraid", "startling creates an Afraid relationship state")

	grace.position = Vector3(30.0, 0.5, 30.0)
	sheep.perception.reset()
	noise_position = sheep.global_position + Vector3(1.0, 0.0, 0.0)
	noise_strength = 1.2
	sheep.force_decision()
	var hearing: Dictionary = sheep.get_perception_data()
	_expect(not bool(hearing.get("can_see_target", true)), "distant Grace is outside the sheep's sight range during the hearing test")
	_expect(bool(hearing.get("can_hear_target", false)), "animals can hear a nearby disturbance without seeing Grace")
	_expect(str(hearing.get("stimulus_kind", "")) == "hearing", "hearing records the correct stimulus kind")
	noise_strength = 0.0

	var wolf_one: GenericAnimalActor = _spawn_animal(
		"Alert Wolf",
		"wolf",
		"balanced",
		Vector3(-1.2, 0.5, 0.0)
	)
	var wolf_two: GenericAnimalActor = _spawn_animal(
		"Listening Wolf",
		"wolf",
		"balanced",
		Vector3(1.2, 0.5, 0.0)
	)
	wolf_one.rotation.y = 0.0
	wolf_two.rotation.y = PI
	grace.position = Vector3(-1.2, 0.5, -3.0)
	threatening = true
	await get_tree().process_frame
	wolf_one.perception.reset()
	wolf_two.perception.reset()
	wolf_one.force_decision()
	_expect(wolf_one.perception.can_see_target, "front-facing wolf visually detects threatening Grace")
	_expect(wolf_one.perception.awareness >= 0.9, "forced visual refresh immediately raises wolf awareness")
	_expect(wolf_two.perception.social_alert_remaining > 0.0, "wolf shares its alert with a nearby packmate")
	_expect(wolf_two.get_drive("territorial_pressure") > 0.0, "pack alert creates territorial pressure in the listening wolf")

	for actor: GenericAnimalActor in actors:
		actor.queue_free()
	await get_tree().process_frame
	_finish()


func _spawn_animal(
	name_value: String,
	species: String,
	profile: String,
	position_value: Vector3
) -> GenericAnimalActor:
	var actor := AnimalScript.new() as GenericAnimalActor
	actor.animal_name = name_value
	actor.species_id = species
	actor.personality_profile_id = profile
	actor.decision_interval = 10.0
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
	return noise_position


func get_animal_noise_strength(_animal: GenericAnimalActor) -> float:
	return noise_strength


func get_animal_forage_position(animal: GenericAnimalActor) -> Vector3:
	return animal.home_position


func get_animal_water_position(animal: GenericAnimalActor) -> Vector3:
	return animal.home_position + Vector3(4.0, 0.0, 0.0)


func broadcast_animal_alert(
	source: GenericAnimalActor,
	position_value: Vector3,
	severity: float
) -> void:
	for actor: GenericAnimalActor in actors:
		if actor == source or actor.species_id != source.species_id:
			continue
		if actor.global_position.distance_to(source.global_position) <= 15.0:
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
		print("ANIMAL_PERCEPTION_RELATIONSHIP_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ANIMAL_PERCEPTION_RELATIONSHIP_SMOKE_TEST: " + failure)
	get_tree().quit(1)
