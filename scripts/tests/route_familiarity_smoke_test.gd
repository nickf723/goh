extends Node

const WildsScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_wilds_expedition_v1.tscn")
const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const ExpeditionStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")
const PlannerScript = preload("res://scripts/expedition/route_familiarity_planner.gd")

const TEST_NETWORK_PATH: String = "user://route_familiarity_network_test.json"
const TEST_EXPEDITION_PATH: String = "user://route_familiarity_expedition_test.json"


func _ready() -> void:
	RegionalStoreScript.delete_record(TEST_NETWORK_PATH)
	ExpeditionStoreScript.delete_record(TEST_EXPEDITION_PATH)
	get_tree().root.remove_meta("regional_expedition_launch")

	assert_plan_indices(
		RegionalStoreScript.ROUTE_MAIN,
		RegionalStoreScript.STATE_DISCOVERED,
		[0, 1, 2, 3, 4]
	)
	assert_plan_indices(
		RegionalStoreScript.ROUTE_MAIN,
		RegionalStoreScript.STATE_STABILIZED,
		[0, 2, 4]
	)
	assert_plan_indices(
		RegionalStoreScript.ROUTE_CYPRESS_CAIRN,
		RegionalStoreScript.STATE_DISCOVERED,
		[0, 1]
	)
	assert_plan_indices(
		RegionalStoreScript.ROUTE_CYPRESS_CAIRN,
		RegionalStoreScript.STATE_STABILIZED,
		[1]
	)
	assert_plan_indices(
		RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE,
		RegionalStoreScript.STATE_DISCOVERED,
		[2, 3, 4]
	)
	assert_plan_indices(
		RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE,
		RegionalStoreScript.STATE_STABILIZED,
		[2, 4]
	)

	var seed_record: Dictionary = RegionalStoreScript.create_record()
	var initial_seed: int = RegionalStoreScript.get_route_seed(
		seed_record,
		RegionalStoreScript.ROUTE_MAIN
	)
	seed_record = RegionalStoreScript.complete_route(
		seed_record,
		RegionalStoreScript.ROUTE_MAIN,
		RegionalStoreScript.NODE_BLUE_RIDGE,
		"test-plan"
	)
	assert(
		RegionalStoreScript.get_route_seed(seed_record, RegionalStoreScript.ROUTE_MAIN)
		!= initial_seed
	)
	assert(
		RegionalStoreScript.get_route_journey_index(seed_record, RegionalStoreScript.ROUTE_MAIN)
		== 1
	)

	await assert_assembled_slice(
		RegionalStoreScript.ROUTE_MAIN,
		RegionalStoreScript.STATE_DISCOVERED,
		RegionalStoreScript.NODE_CYPRESS,
		RegionalStoreScript.NODE_BLUE_RIDGE,
		["cypress_basin", "wet_woodland", "pine_ridge", "rocky_foothills", "mountain_forest"]
	)
	await assert_assembled_slice(
		RegionalStoreScript.ROUTE_CYPRESS_CAIRN,
		RegionalStoreScript.STATE_DISCOVERED,
		RegionalStoreScript.NODE_CYPRESS,
		RegionalStoreScript.NODE_CAIRN,
		["cypress_basin", "wet_woodland"]
	)
	await assert_assembled_slice(
		RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE,
		RegionalStoreScript.STATE_STABILIZED,
		RegionalStoreScript.NODE_CAIRN,
		RegionalStoreScript.NODE_BLUE_RIDGE,
		["pine_ridge", "mountain_forest"]
	)

	RegionalStoreScript.delete_record(TEST_NETWORK_PATH)
	ExpeditionStoreScript.delete_record(TEST_EXPEDITION_PATH)
	get_tree().root.remove_meta("regional_expedition_launch")
	print("ROUTE_FAMILIARITY_SMOKE_TEST: PASS")
	get_tree().quit()


func assert_plan_indices(route_id: String, state_name: String, expected: Array[int]) -> void:
	var plan: Dictionary = PlannerScript.build_plan(
		route_id,
		state_name,
		RegionalStoreScript.get_default_route_seed(route_id),
		RegionalStoreScript.NODE_CYPRESS,
		RegionalStoreScript.NODE_BLUE_RIDGE
	)
	var actual_value: Variant = plan.get("source_indices", [])
	assert(actual_value is Array)
	var actual: Array = actual_value as Array
	assert(actual.size() == expected.size())
	for index: int in range(expected.size()):
		assert(int(actual[index]) == expected[index])
	assert(str(plan.get("signature", "")) != "")
	assert(not PlannerScript.build_preview_text(plan).is_empty())


func assert_assembled_slice(
	route_id: String,
	state_name: String,
	origin_node_id: String,
	destination_node_id: String,
	expected_segment_ids: Array[String]
) -> void:
	var seed_value: int = RegionalStoreScript.get_default_route_seed(route_id)
	var plan: Dictionary = PlannerScript.build_plan(
		route_id,
		state_name,
		seed_value,
		origin_node_id,
		destination_node_id
	)
	get_tree().root.set_meta("regional_expedition_launch", {
		"route_id": route_id,
		"route_state": state_name,
		"route_seed": seed_value,
		"origin_node_id": origin_node_id,
		"destination_node_id": destination_node_id,
		"network_record_path": TEST_NETWORK_PATH,
		"expedition_record_path": TEST_EXPEDITION_PATH,
		"map_scene_path": "",
		"suppress_scene_transition": true,
		"familiarity_plan": plan,
		"plan_signature": str(plan.get("signature", "")),
	})

	var route: Node = WildsScene.instantiate()
	assert(route != null)
	add_child(route)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(bool(route.get("launched_from_regional_map")))
	assert(bool(route.get("route_valid")))
	var segments_value: Variant = route.get("main_segments")
	assert(segments_value is Array)
	var segments: Array = segments_value as Array
	assert(segments.size() == expected_segment_ids.size())
	for index: int in range(expected_segment_ids.size()):
		var segment: Node = segments[index] as Node
		assert(segment != null)
		var definition_value: Variant = segment.get("definition")
		assert(definition_value is ExpeditionSegmentDefinition)
		var definition: ExpeditionSegmentDefinition = definition_value as ExpeditionSegmentDefinition
		assert(definition.segment_id == expected_segment_ids[index])

	var expected_habitat_ids: Array[String] = []
	var expected_animal_count: int = 0
	for segment_id: String in expected_segment_ids:
		if segment_id in [
			"cypress_basin",
			"wet_woodland",
			"pine_ridge",
		]:
			expected_habitat_ids.append(segment_id)
			expected_animal_count += 2 if segment_id == "cypress_basin" else 1
	var habitats_value: Variant = route.get("wildlife_habitats")
	assert(habitats_value is Array)
	var habitats: Array = habitats_value as Array
	assert(habitats.size() == expected_habitat_ids.size())
	assert(int(route.call("get_wildlife_animal_count")) == expected_animal_count)
	for habitat_value: Variant in habitats:
		assert(habitat_value is Node)
		var habitat: Node = habitat_value as Node
		var habitat_id_value: String = str(habitat.get("habitat_id"))
		assert(expected_habitat_ids.has(habitat_id_value))
		var animals_value: Variant = habitat.call("get_animals")
		assert(animals_value is Array)
		assert(not (animals_value as Array).is_empty())
		for animal_value: Variant in animals_value as Array:
			assert(animal_value is GenericAnimalActor)
			var animal: GenericAnimalActor = (
				animal_value as GenericAnimalActor
			)
			match habitat_id_value:
				"cypress_basin":
					assert(
						animal.get_active_locomotion_mode()
						== "swimmer"
					)
				"wet_woodland":
					assert(
						animal.get_active_locomotion_mode()
						== "climber"
					)
				"pine_ridge":
					assert(
						animal.get_active_locomotion_mode()
						== "burrower"
					)

	route.queue_free()
	await get_tree().process_frame
	get_tree().root.remove_meta("regional_expedition_launch")
