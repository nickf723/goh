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

	route.assemble_full_expedition()
	await get_tree().process_frame
	assert(route.route_valid)
	assert(route.get_route_signature() == original_signature)
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

	RecordStoreScript.delete_record(TEST_RECORD_PATH)
	print("WILDS_EXPEDITION_SMOKE_TEST: PASS")
	get_tree().quit()
