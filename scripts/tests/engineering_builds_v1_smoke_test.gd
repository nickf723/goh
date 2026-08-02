extends Node

const YardScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_engineering_build_yard_v1.tscn"
)
const BuildCatalog = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
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
	for _index: int in range(20):
		await get_tree().process_frame
	await get_tree().physics_frame

	manager = get_tree().get_first_node_in_group(
		"engineering_build_manager"
	) as EngineeringBuildManager
	assert_true(yard != null, "engineering build yard instantiates")
	assert_true(manager != null, "engineering build manager exists")
	assert_equal(
		get_tree().get_nodes_in_group("engineering_build_station").size(),
		4,
		"four engineering build stations exist"
	)
	assert_true(
		BuildCatalog.validate_catalog().is_empty(),
		"engineering build catalog validates"
	)
	if yard == null or manager == null:
		_restore_state()
		_finish()
		return

	var blocked: Dictionary = manager.save_build("bridge_frame")
	assert_true(
		not bool(blocked.get("ok", true)),
		"build save is blocked before component blueprints are recorded"
	)
	assert_true(
		(blocked.get("missing", []) as Array).size() >= 2,
		"blocked build reports missing components"
	)

	yard.call("save_all_builds_for_debug")
	await get_tree().process_frame
	assert_equal(
		ObjectCatalog.get_recorded_blueprint_ids().size(),
		4,
		"debug preparation records all component objects"
	)
	assert_equal(
		BuildCatalog.get_saved_build_ids().size(),
		4,
		"all four engineering builds can be saved"
	)
	for build_id: String in BuildCatalog.BUILD_ORDER:
		assert_equal(
			GameState.get_inventory_count(BuildCatalog.get_item_id(build_id)),
			1,
			build_id + " creates one persistent build blueprint"
		)

	var inventory_rows: Array[Dictionary] = GameState.get_inventory_rows()
	var build_rows: Array[Dictionary] = ItemCategoryCatalog.get_rows_for_category(
		inventory_rows,
		"builds"
	)
	assert_true(
		build_rows.size() >= 4,
		"Items Builds shelf receives engineering blueprints"
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
		"Journal Blueprints shelf receives all engineering builds"
	)

	manager.select_build("bridge_frame")
	var bridge: EngineeringBuildInstance = manager.place_selected_at(
		Vector3(-8.0, 0.0, 0.0),
		0.0,
		true,
		true
	)
	assert_true(bridge != null, "bridge frame can be reproduced")
	if bridge != null:
		assert_true(bridge.freeze, "bridge frame is anchored")
		assert_equal(bridge.build_id, "bridge_frame", "bridge keeps build identity")

	manager.select_build("launch_tower")
	var tower: EngineeringBuildInstance = manager.place_selected_at(
		Vector3(7.0, 0.0, 3.0),
		0.0,
		true,
		true
	)
	assert_true(tower != null, "launch tower can be reproduced")
	if tower != null:
		assert_true(
			bool(tower.get_debug_data().get("has_spring_trigger", false)),
			"launch tower creates a launch trigger"
		)
		var lightning := _make_payload("lightning", 3, 1.0, 0.0, ["electrical"])
		tower.receive_damage_payload(lightning)
		assert_equal(
			int(tower.get_debug_data().get("overcharge_charges", 0)),
			3,
			"Lightning gives launch tower three overcharge charges"
		)
		var player: CharacterBody3D = yard.get_node_or_null("Player") as CharacterBody3D
		if player != null:
			player.velocity.y = 0.0
			tower.call("_on_launch_body_entered", player)
			assert_true(
				player.velocity.y >= 20.0,
				"overcharged launch tower boosts the player"
			)
			assert_equal(
				int(tower.get_debug_data().get("overcharge_charges", 0)),
				2,
				"boosted launch consumes one charge"
			)

	manager.select_build("conductive_raft")
	var raft: EngineeringBuildInstance = manager.place_selected_at(
		Vector3(7.5, 1.8, -11.0),
		0.0,
		true,
		true
	)
	assert_true(raft != null, "conductive raft can be reproduced")
	if raft != null:
		for _index: int in range(4):
			await get_tree().physics_frame
		raft.call("_apply_raft_buoyancy")
		assert_true(
			float(raft.get_debug_data().get("submerged_fraction", 0.0)) > 0.0,
			"conductive raft binds to shared water volume"
		)
		raft.receive_damage_payload(
			_make_payload("lightning", 3, 1.0, 0.0, ["electrical"])
		)
		assert_true(
			float(raft.get_debug_data().get("energized_remaining", 0.0)) > 0.0,
			"Lightning energizes the conductive raft"
		)

	manager.select_build("blast_cart")
	var cart: EngineeringBuildInstance = manager.place_selected_at(
		Vector3(-7.0, 0.0, -10.0),
		0.0,
		true,
		true
	)
	assert_true(cart != null, "blast cart can be reproduced")
	if cart != null:
		cart.receive_damage_payload(
			_make_payload("water", 3, 1.0, 0.0, ["douse"])
		)
		cart.receive_damage_payload(
			_make_payload("fire", 3, 1.0, 0.0, ["ignite"])
		)
		assert_true(
			not cart.detonation_started,
			"water dampens the Blast Cart fuse"
		)
		cart.wet_remaining = 0.0
		cart.receive_damage_payload(
			_make_payload("fire", 3, 1.0, 0.0, ["ignite"])
		)
		await get_tree().physics_frame
		await get_tree().physics_frame
		assert_true(
			not is_instance_valid(cart) or cart.is_queued_for_deletion(),
			"dry Blast Cart detonates from Fire"
		)

	var moved_target: bool = false
	for target: Node in get_tree().get_nodes_in_group("engineering_build_test_target"):
		if target is RigidBody3D and (target as RigidBody3D).linear_velocity.length() > 0.05:
			moved_target = true
	assert_true(moved_target, "Blast Cart applies force to nearby targets")

	manager.select_build("bridge_frame")
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
		"bridge active limit replaces the oldest copy"
	)
	var overlap_result: Dictionary = manager.validate_placement(
		BuildCatalog.get_definition("bridge_frame"),
		Vector3(0.0, 0.0, 8.0),
		0.0
	)
	assert_true(
		not bool(overlap_result.get("valid", true)),
		"engineering placement rejects occupied space"
	)

	manager.clear_spawned_builds()
	await get_tree().process_frame
	assert_equal(manager.get_active_count(), 0, "clear removes every engineering build")
	var debug: Dictionary = yard.call("get_engineering_debug_data") as Dictionary
	assert_equal(debug.get("saved_count"), 4, "yard debug data exposes saved builds")
	assert_equal(debug.get("station_count"), 4, "yard debug data exposes build stations")
	assert_true(bool(debug.get("has_water_basin", false)), "yard exposes a shared water basin")

	_restore_state()
	_finish()


func _make_payload(
	element: String,
	amount: int,
	strength: float,
	knockback: float,
	tags: Array[String]
) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.element = element
	payload.amount = amount
	payload.stance_damage = amount
	payload.status_strength = strength
	payload.knockback_strength = knockback
	payload.source_name = "Engineering Build Smoke Test"
	payload.hit_type = "environment"
	payload.tags = tags
	return payload


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
