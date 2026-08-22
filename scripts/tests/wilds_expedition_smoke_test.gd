extends Node

const RouteScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_wilds_expedition_v1.tscn")
const RecordStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")
const TEST_RECORD_PATH: String = "user://wilds_expedition_smoke_test.json"


func _ready() -> void:
	RecordStoreScript.delete_record(TEST_RECORD_PATH)
	var route: ExpeditionRouteGenerator = RouteScene.instantiate() as ExpeditionRouteGenerator
	assert(route != null)
	route.record_path = TEST_RECORD_PATH
	add_child(route)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(route.route_valid)
	assert(route.main_segments.size() == 5)
	assert(route.branch_segment != null)
	assert(route.landmark_marker != null)
	assert(route.destination_marker != null)
	assert(route.get_route_signature() != "")
	assert_wildlife_habitats(route)

	var original_signature: String = route.get_route_signature()
	var discovery_result: Dictionary = route.activate_route_marker("landmark", "old_survey_cairn")
	assert(not discovery_result.is_empty())
	assert(route.is_marker_recorded("landmark", "old_survey_cairn"))
	assert(bool(route.route_record.get("shortcut_unlocked", false)))

	var stale_marker: Area3D = route.landmark_marker as Area3D
	assert(stale_marker != null)
	route.player.set("lock_on_target", stale_marker)
	route.player.set("current_interactable", stale_marker)
	var nearby_interactables: Array[Area3D] = [stale_marker]
	route.player.set("nearby_interactables", nearby_interactables)

	var stale_habitats: Array = route.call("get_wildlife_habitats") as Array
	var stale_habitat: Node = stale_habitats[0] as Node
	route.assemble_full_expedition()
	await get_tree().process_frame
	assert(route.route_valid)
	assert(not is_instance_valid(stale_habitat))
	assert(route.get_route_signature() == original_signature)
	assert_wildlife_habitats(route)
	assert(route.is_marker_recorded("landmark", "old_survey_cairn"))
	assert(route.player.get("lock_on_target") == null)
	assert(route.player.get("current_interactable") == null)
	var nearby_after_rebuild: Variant = route.player.get("nearby_interactables")
	assert(nearby_after_rebuild is Array)
	assert((nearby_after_rebuild as Array).is_empty())

	var weapon_controller: Node = route.player.get_node_or_null("WeaponController")
	assert(weapon_controller != null)
	weapon_controller.call("try_light_attack")
	await get_tree().process_frame
	await get_tree().process_frame

	route.generate_new_route_seed()
	route.assemble_full_expedition()
	await get_tree().process_frame
	assert(route.route_valid)
	assert(route.get_route_signature() != original_signature)
	assert(route.is_marker_recorded("landmark", "old_survey_cairn"))
	assert_wildlife_habitats(route)

	RecordStoreScript.delete_record(TEST_RECORD_PATH)
	print("WILDS_EXPEDITION_SMOKE_TEST: PASS")
	get_tree().quit()


func assert_wildlife_habitats(
	route: ExpeditionRouteGenerator
) -> void:
	assert(route.has_method("get_wildlife_habitats"))
	assert(route.has_method("get_wildlife_animal_count"))
	var habitats_value: Variant = route.call("get_wildlife_habitats")
	assert(habitats_value is Array)
	var habitats: Array = habitats_value as Array
	assert(habitats.size() == 3)
	assert(int(route.call("get_wildlife_animal_count")) == 4)
	var habitats_by_id: Dictionary = {}
	for habitat_value: Variant in habitats:
		assert(habitat_value is Node)
		var habitat: Node = habitat_value as Node
		var habitat_id_value: String = str(habitat.get("habitat_id"))
		habitats_by_id[habitat_id_value] = habitat
		assert(habitat.is_in_group("wilds_animal_habitat"))
		var debug_value: Variant = habitat.call("get_debug_data")
		assert(debug_value is Dictionary)
		assert(bool((debug_value as Dictionary).get(
			"wilds_animal_habitat",
			false
		)))
		var animals_value: Variant = habitat.call("get_animals")
		assert(animals_value is Array)
		for animal_value: Variant in animals_value as Array:
			assert(animal_value is GenericAnimalActor)
			var animal: GenericAnimalActor = (
				animal_value as GenericAnimalActor
			)
			assert(animal.state_label != null)
			assert(not animal.state_label.visible)
			assert(
				habitat.call(
					"get_animal_grace_target",
					animal
				)
				== route.player
			)

	assert(habitats_by_id.has("cypress_basin"))
	assert(habitats_by_id.has("wet_woodland"))
	assert(habitats_by_id.has("pine_ridge"))

	var cypress: Node = habitats_by_id["cypress_basin"] as Node
	var cypress_species: Array[String] = _string_array(
		cypress.call("get_species_ids")
	)
	assert(cypress_species.has("goose"))
	assert(cypress_species.has("trout"))
	assert(cypress.get("water_volume") is SwimmingWaterVolume)
	for animal_value: Variant in cypress.call("get_animals") as Array:
		var animal: GenericAnimalActor = (
			animal_value as GenericAnimalActor
		)
		assert(animal.get_active_locomotion_mode() == "swimmer")

	var woodland: Node = habitats_by_id["wet_woodland"] as Node
	assert(_string_array(woodland.call("get_species_ids")) == ["gecko"])
	var gecko: GenericAnimalActor = (
		(woodland.call("get_animals") as Array)[0]
		as GenericAnimalActor
	)
	assert(gecko.get_active_locomotion_mode() == "climber")
	var climb_medium: Variant = woodland.get("traversal_medium")
	assert(climb_medium is MobTraversalMedium)
	assert(
		(climb_medium as MobTraversalMedium).get_locomotion_mode()
		== "climber"
	)
	var climb_guidance: Dictionary = (
		climb_medium as MobTraversalMedium
	).get_guidance_target(gecko)
	assert(bool(climb_guidance.get("found", false)))

	var ridge: Node = habitats_by_id["pine_ridge"] as Node
	assert(_string_array(ridge.call("get_species_ids")) == ["mole"])
	var mole: GenericAnimalActor = (
		(ridge.call("get_animals") as Array)[0]
		as GenericAnimalActor
	)
	assert(mole.get_active_locomotion_mode() == "burrower")
	var burrow_medium: Variant = ridge.get("traversal_medium")
	assert(burrow_medium is MobTraversalMedium)
	assert(
		(burrow_medium as MobTraversalMedium).get_locomotion_mode()
		== "burrower"
	)
	var burrow_guidance: Dictionary = (
		burrow_medium as MobTraversalMedium
	).get_guidance_target(mole)
	assert(bool(burrow_guidance.get("found", false)))

	var route_debug: Dictionary = route.get_debug_data()
	assert(int(route_debug.get("wildlife_habitats", 0)) == 3)
	assert(int(route_debug.get("wildlife_animals", 0)) == 4)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			result.append(str(entry))
	return result
