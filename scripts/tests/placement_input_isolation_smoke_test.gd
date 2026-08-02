extends Node

const YardScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_engineering_build_yard_v1.tscn"
)

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var yard: Node3D


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_blueprint_state()
	yard = YardScene.instantiate() as Node3D
	add_child(yard)
	for _index: int in range(24):
		await get_tree().process_frame

	var player: Node = yard.get_node_or_null("Player")
	var bootstrap: WeaponInputBootstrap = (
		player.get_node_or_null("WeaponController/WeaponInputBootstrap")
		as WeaponInputBootstrap
		if player != null
		else null
	)
	var build_manager: EngineeringBuildManager = get_tree().get_first_node_in_group(
		"engineering_build_manager"
	) as EngineeringBuildManager
	var object_managers: Array[Node] = get_tree().get_nodes_in_group(
		"recorded_object_manager"
	)

	assert_true(yard != null, "engineering yard instantiates")
	assert_true(player != null, "player exists")
	assert_true(bootstrap != null, "weapon input bootstrap exists")
	assert_true(build_manager != null, "engineering build manager exists")
	assert_true(not object_managers.is_empty(), "recorded object manager exists")
	if bootstrap == null or build_manager == null:
		_restore_state()
		_finish()
		return

	assert_true(
		bool(bootstrap.get_debug_data().get("placement_input_isolated", false)),
		"player input bootstrap reports placement isolation"
	)
	assert_true(
		not build_manager.placement_active,
		"engineering placement begins dormant"
	)
	assert_true(
		not build_manager.controller_controls_enabled,
		"dormant engineering manager ignores controller buttons"
	)
	for raw_manager: Node in object_managers:
		var object_manager := raw_manager as RecordedObjectManager
		if object_manager == null:
			continue
		assert_true(
			not object_manager.controller_controls_enabled,
			"dormant recorded object manager ignores controller buttons"
		)

	yard.call("save_all_builds_for_debug")
	await get_tree().process_frame
	var stations: Array[Node] = get_tree().get_nodes_in_group(
		"engineering_build_station"
	)
	assert_true(not stations.is_empty(), "engineering build stations exist")
	if not stations.is_empty():
		var result: Dictionary = stations[0].call("interact") as Dictionary
		assert_true(
			str(result.get("message", "")).begins_with("Placing"),
			"interacting with a saved build station enters placement"
		)
	await get_tree().process_frame
	assert_true(
		build_manager.placement_active,
		"build placement becomes active deliberately"
	)
	assert_true(
		build_manager.controller_controls_enabled,
		"placement mode owns controller confirmation controls"
	)

	build_manager.cancel_placement()
	await get_tree().process_frame
	assert_true(
		not build_manager.controller_controls_enabled,
		"cancelling placement returns controller ownership to combat"
	)

	var light_events: Array[InputEvent] = InputMap.action_get_events(
		&"weapon_light_attack"
	)
	var has_shoulder_attack: bool = false
	for event: InputEvent in light_events:
		if event is InputEventJoypadButton:
			var button := event as InputEventJoypadButton
			if button.button_index in [
				JOY_BUTTON_LEFT_SHOULDER,
				JOY_BUTTON_RIGHT_SHOULDER,
			]:
				has_shoulder_attack = true
	assert_true(
		has_shoulder_attack,
		"light attack retains its shoulder-button binding"
	)

	_restore_state()
	_finish()


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)


func _clear_blueprint_state() -> void:
	for item_id: String in [
		"recorded_crate_blueprint",
		"recorded_platform_blueprint",
		"recorded_spring_blueprint",
		"recorded_blast_barrel_blueprint",
		"bridge_frame_blueprint",
		"launch_tower_blueprint",
		"blast_cart_blueprint",
		"conductive_raft_blueprint",
	]:
		GameState.inventory.erase(item_id)
	GameState.story_flags.erase("__recorded_objects__::selected_blueprint")
	GameState.story_flags.erase("__engineering_builds__::selected_build")


func _restore_state() -> void:
	if yard != null and is_instance_valid(yard):
		yard.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("PLACEMENT_INPUT_ISOLATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PLACEMENT_INPUT_ISOLATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
