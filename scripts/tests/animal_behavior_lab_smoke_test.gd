extends Node3D

const AnimalScript = preload("res://scripts/animals/generic_animal_actor.gd")
const LabScene = preload("res://scenes/levels/prototypes/animal_behavior_lab_v1.tscn")

var failures: Array[String] = []
var threat_mode: bool = false
var threat: Node3D
var forage_position: Vector3 = Vector3.ZERO
var water_position: Vector3 = Vector3(5.0, 0.0, 0.0)
var noise_position: Vector3 = Vector3.ZERO
var noise_strength: float = 0.0


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_build_floor()
	threat = Node3D.new()
	threat.position = Vector3(0.0, 0.5, 8.0)
	add_child(threat)
	var animal := AnimalScript.new() as GenericAnimalActor
	animal.species_id = "sheep"
	animal.animal_name = "Test Sheep"
	animal.personality_profile_id = "cautious"
	animal.decision_interval = 5.0
	animal.position = Vector3(0.0, 0.5, 0.0)
	add_child(animal)
	await get_tree().process_frame
	await get_tree().physics_frame
	_expect(animal.brain != null, "generic animal creates a MobBrainComponent")
	_expect(animal.perception != null, "generic animal creates perception memory")
	_expect(animal.relationship != null, "generic animal creates a Grace relationship")
	_expect(animal.state_label != null, "generic animal builds visible debug presentation")
	animal.set_drive("hunger", 1.0)
	var graze_decision: Dictionary = animal.force_decision()
	_expect(str(graze_decision.get("move_id", "")) == "graze", "hungry safe sheep selects Graze")
	_expect(animal.current_action_id == "graze", "selected Graze becomes a live actor action")
	_expect(animal.current_intention_id == "forage", "live actor exposes the Forage intention")
	_expect(animal.get_drive("hunger") < 1.0, "committing Graze satisfies some hunger")

	threat.position = Vector3(0.0, 0.5, -1.2)
	threat_mode = true
	animal.perception.reset()
	animal.brain.clear_cooldowns()
	animal.brain.clear_memory()
	animal.set_drive("fear", 1.0)
	var distance_before: float = animal.global_position.distance_to(threat.global_position)
	var flee_decision: Dictionary = animal.force_decision()
	_expect(bool(animal.get_perception_data().get("can_see_target", false)), "sheep sees a close threat in front")
	_expect(str(flee_decision.get("move_id", "")) == "flee", "frightened sheep selects Flee from a perceived threat")
	_expect(animal.current_action_id == "flee", "selected Flee becomes a live movement action")
	for _frame: int in range(24):
		await get_tree().physics_frame
	var distance_after: float = animal.global_position.distance_to(threat.global_position)
	_expect(distance_after > distance_before + 0.2, "Flee execution physically increases threat distance")

	var lab_instance: Node = LabScene.instantiate()
	_expect(lab_instance != null, "playable Animal Behavior Lab scene instantiates")
	if lab_instance != null:
		add_child(lab_instance)
		await get_tree().process_frame
		var buttons: Array[Node] = lab_instance.find_children("*", "Button", true, false)
		_expect(buttons.size() >= 10, "playable lab builds on-screen mouse and controller controls")
		lab_instance.queue_free()
	animal.queue_free()
	await get_tree().process_frame
	_finish()


func get_animal_grace_target(_animal: GenericAnimalActor) -> Node3D:
	return threat


func get_animal_threat_target(_animal: GenericAnimalActor) -> Node3D:
	return threat


func is_grace_threatening(_animal: GenericAnimalActor) -> bool:
	return threat_mode


func is_animal_threat_mode_enabled(_animal: GenericAnimalActor) -> bool:
	return threat_mode


func get_animal_noise_position(_animal: GenericAnimalActor) -> Vector3:
	return noise_position


func get_animal_noise_strength(_animal: GenericAnimalActor) -> float:
	return noise_strength


func get_animal_forage_position(_animal: GenericAnimalActor) -> Vector3:
	return forage_position


func get_animal_water_position(_animal: GenericAnimalActor) -> Vector3:
	return water_position


func broadcast_animal_alert(
	_source: GenericAnimalActor,
	_position: Vector3,
	_severity: float
) -> void:
	pass


func clamp_animal_position(value: Vector3) -> Vector3:
	return value


func _build_floor() -> void:
	var floor := StaticBody3D.new()
	floor.position = Vector3(0.0, -0.25, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.5, 20.0)
	collision.shape = shape
	floor.add_child(collision)
	add_child(floor)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ANIMAL_BEHAVIOR_LAB_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ANIMAL_BEHAVIOR_LAB_SMOKE_TEST: " + failure)
	get_tree().quit(1)
