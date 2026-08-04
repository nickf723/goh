extends Node3D

const LabScene = preload("res://scenes/levels/prototypes/wildlife_navigation_rescue_lab_v1.tscn")
const WildlifeAnimalScript = preload("res://scripts/animals/navigation_bonded_animal_actor.gd")
const TEST_ANIMAL_ID: String = "smoke_test:wildlife_navigation_juniper"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var treats_before: int = GameState.get_inventory_count("field_treat")
	GameState.set_inventory_count("field_treat", 0)
	var lab: Node = LabScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	await _wait_for_navigation(lab, 180)

	_expect(bool(lab.call("is_navigation_ready")), "dedicated lab bakes a usable navigation mesh")
	_expect(int(lab.call("get_navigation_polygon_count")) > 0, "navigation mesh contains walkable polygons")
	var animal: WildlifeAnimalScript = lab.call("get_test_animal") as WildlifeAnimalScript
	var player: Node3D = lab.call("get_test_player") as Node3D
	_expect(animal != null, "dedicated lab spawns the navigation-aware named animal")
	_expect(player != null, "dedicated lab includes the normal playable Grace actor")
	if animal == null or player == null:
		_finish(treats_before, lab, animal)
		return

	animal.persistent_animal_id = TEST_ANIMAL_ID
	animal.clear_persistent_bond()
	animal.set_rescued(false, false)
	animal.set_injured(true, 0.65)
	_expect(animal.movement_locked and not animal.rescued, "animal begins trapped behind rescue debris")
	_expect(animal.injured and animal.injury_ratio >= 0.6, "animal begins visibly injured")

	var pickup_result: Dictionary = lab.call("collect_treat_pickup") as Dictionary
	_expect(bool(pickup_result.get("ok", false)), "physical Field Treat pickup grants inventory")
	_expect(GameState.get_inventory_count("field_treat") == 4, "pickup grants four real Field Treats")

	var trust_before_rescue: float = animal.relationship.trust
	var rescue_result: Dictionary = lab.call("rescue_animal") as Dictionary
	await get_tree().process_frame
	await get_tree().physics_frame
	await _wait_for_navigation(lab, 120)
	_expect(bool(rescue_result.get("ok", false)), "rescue interaction clears the trapped state")
	_expect(animal.rescued and not animal.movement_locked, "rescued animal can move")
	_expect(int(lab.call("get_navigation_bake_count")) >= 2, "removing debris triggers a navigation rebake")
	_expect(animal.relationship.trust > trust_before_rescue, "rescue is reported as a positive relationship event")

	var injury_before: float = animal.injury_ratio
	var trust_before_heal: float = animal.relationship.trust
	var heal_result: Dictionary = lab.call("heal_animal") as Dictionary
	_expect(bool(heal_result.get("ok", false)), "healing reaches the animal relationship bridge")
	_expect(animal.injury_ratio < injury_before, "healing reduces the animal's injury")
	_expect(animal.relationship.trust > trust_before_heal, "healing increases persistent trust")

	player.global_position = animal.global_position + Vector3(0.0, 0.55, 2.5)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	await get_tree().physics_frame
	var feed_one: Dictionary = lab.call("feed_animal") as Dictionary
	var feed_two: Dictionary = lab.call("feed_animal") as Dictionary
	var feed_three: Dictionary = lab.call("feed_animal") as Dictionary
	_expect(
		bool(feed_one.get("ok", false))
		and bool(feed_two.get("ok", false))
		and bool(feed_three.get("ok", false)),
		"three inventory-backed feed interactions succeed nearby"
	)
	_expect(GameState.get_inventory_count("field_treat") == 1, "feeding consumes exactly three Field Treats")
	_expect(bool(animal.get_bond_requirements().get("eligible", false)), "rescue, healing, and feeding make the animal bond-eligible")
	var bond_result: Dictionary = lab.call("bond_animal") as Dictionary
	_expect(bool(bond_result.get("ok", false)), "eligible rescued animal bonds with Grace")
	_expect(animal.bonded and animal.follow_enabled, "bond enables navigation-aware following")

	lab.call("prepare_navigation_test_positions")
	await get_tree().physics_frame
	animal.force_decision(true)
	var distance_before: float = animal.global_position.distance_to(player.global_position)
	var observed_path: bool = false
	for _frame: int in range(360):
		await get_tree().physics_frame
		var nav_data: Dictionary = animal.get_navigation_debug_data()
		observed_path = observed_path or int(nav_data.get("path_point_count", 0)) >= 3
	var distance_after: float = animal.global_position.distance_to(player.global_position)
	var navigation_data: Dictionary = animal.get_navigation_debug_data()
	_expect(int(navigation_data.get("navigation_queries", 0)) > 0, "following queries NavigationAgent3D during physics updates")
	_expect(observed_path, "navigation course produces a multi-point route around static walls")
	_expect(distance_after < distance_before - 3.0, "bonded animal physically closes distance through the obstacle course")

	var trust_before_attack: float = animal.relationship.trust
	var harm_before: int = animal.harm_events
	var attack_result: Dictionary = animal.receive_damage_payload({
		"amount": 2,
		"source_name": "Grace",
	})
	_expect(int(attack_result.get("damage_dealt", 0)) == 2, "weapon-compatible damage payload reaches the animal")
	_expect(animal.relationship.trust < trust_before_attack, "real damage lowers trust")
	_expect(animal.harm_events == harm_before + 1, "real damage increments persistent harm history")
	_expect(animal.injured, "real damage restores the injured state")

	animal.set_drive("fear", 0.0)
	animal.relationship.fear_association = 0.0
	animal.relationship.trust = maxf(animal.relationship.trust, 0.72)
	animal.relationship_label = animal.relationship.get_relationship_label(0.0)
	var recoveries_before: int = int(animal.get_navigation_debug_data().get("recovery_count", 0))
	lab.call("separate_grace")
	for _frame: int in range(90):
		await get_tree().physics_frame
	var recoveries_after: int = int(animal.get_navigation_debug_data().get("recovery_count", 0))
	_expect(recoveries_after > recoveries_before, "severe separation triggers emergency companion recovery")
	_expect(animal.global_position.distance_to(player.global_position) < 7.0, "recovery places the companion safely near Grace")

	var save_result: Dictionary = lab.call("save_bond") as Dictionary
	_expect(bool(save_result.get("ok", false)), "dedicated lab can save the named bond record")
	_finish(treats_before, lab, animal)


func _wait_for_navigation(lab: Node, maximum_frames: int) -> void:
	for _frame: int in range(maximum_frames):
		if bool(lab.call("is_navigation_ready")):
			return
		await get_tree().physics_frame


func _finish(treats_before: int, lab: Node, animal: WildlifeAnimalScript) -> void:
	if animal != null and is_instance_valid(animal):
		animal.clear_persistent_bond()
		animal.persistent_animal_id = ""
	GameState.set_inventory_count("field_treat", treats_before)
	if lab != null and is_instance_valid(lab):
		lab.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("WILDLIFE_NAVIGATION_RESCUE_LAB_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WILDLIFE_NAVIGATION_RESCUE_LAB_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
