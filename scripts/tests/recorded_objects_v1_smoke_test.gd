extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn"
)
const Catalog = preload("res://scripts/objects/recorded_object_catalog.gd")
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
var lab: Node3D
var manager: RecordedObjectManager


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_blueprint_state()
	lab = LabScene.instantiate() as Node3D
	add_child(lab)
	for _index: int in range(16):
		await get_tree().process_frame
	await get_tree().physics_frame

	manager = get_tree().get_first_node_in_group(
		"recorded_object_manager"
	) as RecordedObjectManager
	assert_true(lab != null, "recorded object lab instantiates")
	assert_true(manager != null, "recorded object manager exists")
	assert_equal(
		get_tree().get_nodes_in_group("recorded_object_blueprint_station").size(),
		4,
		"four blueprint stations exist"
	)
	assert_true(Catalog.validate_catalog().is_empty(), "recorded object catalog validates")
	if lab == null or manager == null:
		_restore_state()
		_finish()
		return

	lab.call("record_all_for_debug")
	await get_tree().process_frame
	assert_equal(
		Catalog.get_recorded_blueprint_ids().size(),
		4,
		"all four blueprints can be recorded"
	)
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		assert_equal(
			GameState.get_inventory_count(Catalog.get_item_id(blueprint_id)),
			1,
			blueprint_id + " creates one inventory blueprint record"
		)

	var inventory_rows: Array[Dictionary] = GameState.get_inventory_rows()
	var object_rows: Array[Dictionary] = ItemCategoryCatalog.get_rows_for_category(
		inventory_rows,
		"objects"
	)
	assert_true(object_rows.size() >= 4, "Items Objects shelf receives recorded blueprints")
	var journal_rows: Array[Dictionary] = JournalCatalog.get_blueprint_rows(
		inventory_rows
	)
	var recorded_journal_count: int = 0
	for row: Dictionary in journal_rows:
		if str(row.get("id", "")).begins_with("recorded_"):
			recorded_journal_count += 1
	assert_equal(recorded_journal_count, 4, "Journal Blueprints shelf receives all recorded objects")

	manager.select_blueprint("crate")
	var crate: RecordedObjectInstance = manager.place_selected_at(
		Vector3(-2.0, 0.0, 20.0),
		0.0,
		true,
		true
	)
	assert_true(crate != null, "crate can be reproduced")
	if crate != null:
		assert_true(not crate.freeze, "crate remains a dynamic rigid body")
		assert_equal(crate.blueprint_id, "crate", "crate keeps blueprint identity")

	manager.select_blueprint("platform")
	var platform: RecordedObjectInstance = manager.place_selected_at(
		Vector3(2.0, 0.0, 20.0),
		90.0,
		true,
		true
	)
	assert_true(platform != null, "platform can be reproduced")
	if platform != null:
		assert_true(platform.freeze, "platform is anchored")
		assert_equal(
			str(platform.get_debug_data().get("body_mode", "")),
			"anchored",
			"platform reports anchored body mode"
		)

	manager.select_blueprint("spring")
	var spring: RecordedObjectInstance = manager.place_selected_at(
		Vector3(5.0, 0.0, 20.0),
		0.0,
		true,
		true
	)
	assert_true(spring != null, "spring can be reproduced")
	if spring != null:
		assert_true(
			bool(spring.get_debug_data().get("has_spring_trigger", false)),
			"spring creates a launch trigger"
		)
		var player: CharacterBody3D = lab.get_node_or_null("Player") as CharacterBody3D
		if player != null:
			player.velocity.y = 0.0
			spring.call("_on_spring_body_entered", player)
			assert_true(player.velocity.y >= 10.0, "spring launches the player upward")

	manager.select_blueprint("blast_barrel")
	var barrel: RecordedObjectInstance = manager.place_selected_at(
		Vector3(10.0, 0.0, -7.0),
		0.0,
		true,
		true
	)
	assert_true(barrel != null, "blast barrel can be reproduced")
	var targets: Array[Node] = get_tree().get_nodes_in_group(
		"recorded_object_test_target"
	)
	if barrel != null:
		barrel.detonate()
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert_true(
			barrel.is_queued_for_deletion() or not is_instance_valid(barrel),
			"blast barrel removes itself after detonation"
		)
	var moved_target: bool = false
	for target: Node in targets:
		if target is RigidBody3D and (target as RigidBody3D).linear_velocity.length() > 0.05:
			moved_target = true
	assert_true(moved_target, "blast barrel applies force to nearby rigid targets")

	manager.select_blueprint("crate")
	for index: int in range(5):
		manager.place_selected_at(
			Vector3(-6.0 + float(index) * 1.8, 0.0, 17.0),
			0.0,
			true,
			true
		)
	assert_equal(manager.get_active_count("crate"), 3, "crate active limit replaces oldest copies")
	assert_true(
		manager.get_active_count() <= manager.maximum_total_active,
		"global active-object limit is respected"
	)

	var overlap_definition: Dictionary = Catalog.get_definition("crate")
	var occupied_position: Vector3 = Vector3(-2.4, 0.0, 17.0)
	var overlap_result: Dictionary = manager.validate_placement(
		overlap_definition,
		occupied_position,
		0.0
	)
	assert_true(
		not bool(overlap_result.get("valid", true)),
		"placement validation rejects occupied space"
	)

	manager.clear_spawned_objects()
	await get_tree().process_frame
	assert_equal(manager.get_active_count(), 0, "clear removes every reproduced object")
	var lab_debug: Dictionary = lab.call("get_debug_data") as Dictionary
	assert_equal(lab_debug.get("recorded_count"), 4, "lab debug data exposes recorded progress")
	assert_equal(lab_debug.get("station_count"), 4, "lab debug data exposes station count")

	_restore_state()
	_finish()


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)


func _clear_blueprint_state() -> void:
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(Catalog.get_item_id(blueprint_id))
	GameState.story_flags.erase(Catalog.SELECTED_BLUEPRINT_FLAG)
	for raw_key: Variant in GameState.story_flags.keys():
		var key: String = str(raw_key)
		if key.contains("blueprint") and key.begins_with("__progression__::"):
			GameState.story_flags.erase(raw_key)


func _restore_state() -> void:
	if manager != null and is_instance_valid(manager):
		manager.clear_spawned_objects()
	if lab != null and is_instance_valid(lab):
		lab.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("RECORDED_OBJECTS_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RECORDED_OBJECTS_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
