extends Node

const YardScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_engineering_build_yard_v1.tscn"
)
const BuildCatalog = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
)
const PartCatalog = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)
const ObjectCatalog = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)
const ItemCategoryCatalog = preload(
	"res://scripts/items/item_inventory_category_catalog.gd"
)
const JournalCatalog = preload(
	"res://scripts/journal/journal_record_catalog.gd"
)

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var yard: Node3D
var manager: EngineeringBuildManager


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_test_state()
	yard = YardScene.instantiate() as Node3D
	add_child(yard)
	for _index: int in range(24):
		await get_tree().process_frame
	await get_tree().physics_frame

	manager = get_tree().get_first_node_in_group(
		"engineering_build_manager"
	) as EngineeringBuildManager
	assert_true(yard != null, "engineering build yard instantiates")
	assert_true(manager != null, "legacy engineering build manager exists")
	assert_equal(
		get_tree().get_nodes_in_group("engineering_build_station").size(),
		4,
		"four starter schematic stations exist"
	)
	assert_true(
		BuildCatalog.validate_catalog().is_empty(),
		"part-based engineering catalog validates"
	)
	assert_true(
		PartCatalog.get_unlocked_part_ids().size() >= 3,
		"Artificer runtime establishes a prototype part vocabulary"
	)
	if yard == null or manager == null:
		_restore_state()
		_finish()
		return

	# Starter stations remain a compatibility route. They now save authored part
	# layouts instead of creating a separate monolithic build taxonomy.
	yard.call("save_all_builds_for_debug")
	await get_tree().process_frame
	assert_equal(
		ObjectCatalog.get_recorded_blueprint_ids().size(),
		4,
		"debug preparation preserves recorded object components"
	)
	assert_equal(
		BuildCatalog.get_saved_build_ids().size(),
		4,
		"all four starter schematics can be saved"
	)
	for build_id: String in BuildCatalog.BUILD_ORDER:
		var definition: Dictionary = BuildCatalog.get_definition(build_id)
		assert_true(
			not (definition.get("parts", []) as Array).is_empty(),
			build_id + " exposes its engineering part recipe"
		)
		assert_true(
			int(definition.get("mana_cost", 0)) > 0,
			build_id + " retains a deployment cost"
		)
		assert_equal(
			GameState.get_inventory_count(BuildCatalog.get_item_id(build_id)),
			1,
			build_id + " creates one persistent starter blueprint"
		)

	var inventory_rows: Array[Dictionary] = GameState.get_inventory_rows()
	var build_rows: Array[Dictionary] = ItemCategoryCatalog.get_rows_for_category(
		inventory_rows,
		"builds"
	)
	assert_true(
		build_rows.size() >= 4,
		"Items Builds shelf receives starter schematics"
	)
	var journal_rows: Array[Dictionary] = JournalCatalog.get_blueprint_rows(
		inventory_rows
	)
	var saved_journal_count: int = 0
	for row: Dictionary in journal_rows:
		if str(row.get("id", "")) in [
			"bridge_frame_blueprint",
			"launch_tower_blueprint",
			"blast_cart_blueprint",
			"conductive_raft_blueprint",
		]:
			saved_journal_count += 1
	assert_equal(
		saved_journal_count,
		4,
		"Journal Blueprints shelf receives starter schematics"
	)

	# The original yard manager remains available while players transition to the
	# spell-driven Artificer system. Its placement limits and scene cleanup still
	# form a valid development harness.
	manager.select_build("bridge_frame")
	var bridge: EngineeringBuildInstance = manager.place_selected_at(
		Vector3(-8.0, 0.0, 0.0),
		0.0,
		true,
		true
	)
	assert_true(bridge != null, "legacy yard can place the Bridge Frame starter")
	if bridge != null:
		assert_true(bridge.freeze, "Bridge Frame remains anchored")
		assert_equal(bridge.build_id, "bridge_frame", "starter identity remains stable")

	manager.clear_spawned_builds()
	for index: int in range(3):
		manager.place_selected_at(
			Vector3(-6.0 + float(index) * 6.0, 0.0, 8.0),
			0.0,
			true,
			true
		)
	assert_equal(
		manager.get_active_count("bridge_frame"),
		2,
		"legacy yard still enforces the starter active limit"
	)
	var overlap_result: Dictionary = manager.validate_placement(
		BuildCatalog.get_definition("bridge_frame"),
		Vector3(0.0, 0.0, 8.0),
		0.0
	)
	assert_true(
		not bool(overlap_result.get("valid", true)),
		"legacy yard still rejects occupied placement"
	)

	manager.clear_spawned_builds()
	await get_tree().process_frame
	assert_equal(manager.get_active_count(), 0, "yard cleanup removes starter builds")
	var debug: Dictionary = yard.call("get_engineering_debug_data") as Dictionary
	assert_equal(debug.get("saved_count"), 4, "yard debug data exposes saved starters")
	assert_equal(debug.get("station_count"), 4, "yard debug data exposes stations")
	assert_true(bool(debug.get("has_water_basin", false)), "yard retains its shared water basin")

	_restore_state()
	_finish()


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)


func _clear_test_state() -> void:
	for blueprint_id: String in ObjectCatalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(ObjectCatalog.get_item_id(blueprint_id))
	for build_id: String in BuildCatalog.BUILD_ORDER:
		GameState.inventory.erase(BuildCatalog.get_item_id(build_id))
	GameState.story_flags.erase(ObjectCatalog.SELECTED_BLUEPRINT_FLAG)
	GameState.story_flags.erase(BuildCatalog.SELECTED_BUILD_FLAG)
	GameState.story_flags.erase(BuildCatalog.CUSTOM_BLUEPRINTS_FLAG)
	for raw_key: Variant in GameState.story_flags.keys():
		var key: String = str(raw_key)
		if key.begins_with("__progression__::") and (
			key.contains("blueprint")
			or key.contains("build_reaction")
		):
			GameState.story_flags.erase(raw_key)


func _restore_state() -> void:
	if manager != null and is_instance_valid(manager):
		manager.clear_spawned_builds()
	if yard != null and is_instance_valid(yard):
		yard.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("ENGINEERING_BUILDS_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ENGINEERING_BUILDS_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
