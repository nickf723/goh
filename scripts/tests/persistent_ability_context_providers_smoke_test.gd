extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const RecordedAbility: AbilityDefinition = preload(
	"res://data/abilities/recorded_object_summon_ability.tres"
)
const AssemblyAbility: AbilityDefinition = preload(
	"res://data/abilities/artificer_assembly_ability.tres"
)
const DeployAbility: AbilityDefinition = preload(
	"res://data/abilities/deploy_contraption_ability.tres"
)
const RecordedCatalog = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)
const PartCatalog = preload(
	"res://scripts/builds/engineering_part_catalog.gd"
)
const BuildCatalog = preload(
	"res://scripts/builds/engineering_build_catalog.gd"
)

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var old_time_scale: float = 1.0

var player: CharacterBody3D
var floor: StaticBody3D
var router: Node
var menu: Node
var placement: PlayerSharedPlacementController
var control_router: Node
var action_state: PlayerActionState
var recorded_controller: PlayerRecordedObjectSpellController
var artificer_controller: PlayerArtificerSpellController
var recorded_manager: RecordedObjectManagerSpell
var artificer_manager: ArtificerConstructionManager


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_prepare_test_state()
	floor = _make_floor()
	add_child(floor)
	player = PlayerScene.instantiate() as CharacterBody3D
	player.name = "PersistentAbilityContextProviderTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	add_child(player)
	for _frame: int in range(12):
		await get_tree().process_frame
	await get_tree().physics_frame

	router = player.get_node_or_null("AbilityContextRouter")
	menu = player.get_node_or_null("AbilityContextMenu")
	placement = player.get_node_or_null(
		"SharedPlacementController"
	) as PlayerSharedPlacementController
	control_router = player.get_node_or_null("PlayerControlRouter")
	action_state = player.get_node_or_null("PlayerActionState") as PlayerActionState
	recorded_controller = player.get_node_or_null(
		"RecordedObjectSpellController"
	) as PlayerRecordedObjectSpellController
	artificer_controller = player.get_node_or_null(
		"ArtificerSpellController"
	) as PlayerArtificerSpellController
	if recorded_controller != null:
		recorded_manager = recorded_controller.get_manager()
	if artificer_controller != null:
		artificer_manager = artificer_controller.get_manager()

	_expect(router != null, "player installs the global ability context router")
	_expect(menu != null, "player installs one shared ability context menu")
	_expect(placement != null, "player installs one shared placement controller")
	_expect(control_router != null, "player retains the contextual control router")
	_expect(action_state != null, "player retains shared action state")
	_expect(recorded_controller != null, "recorded-object context provider exists")
	_expect(artificer_controller != null, "Artificer context provider exists")
	_expect(recorded_manager != null, "recorded-object manager exists")
	_expect(artificer_manager != null, "Artificer manager exists")
	if (
		router == null
		or menu == null
		or placement == null
		or action_state == null
		or recorded_controller == null
		or artificer_controller == null
		or recorded_manager == null
		or artificer_manager == null
	):
		await _cleanup_and_finish()
		return

	await _test_recorded_object_context()
	await _test_artificer_assembly_context()
	await _test_deploy_context()
	await _cleanup_and_finish()


func _test_recorded_object_context() -> void:
	RecordedCatalog.select_blueprint("crate")
	var opened: Dictionary = router.call(
		"try_open_context",
		player,
		RecordedAbility
	) as Dictionary
	_expect(bool(opened.get("handled", false)), "Recorded Object is claimed by the global context router")
	_expect(bool(opened.get("success", false)), "Recorded Object opens the shared context")
	var actions: Array[String] = _string_array(menu.call("get_available_action_ids"))
	_expect(actions.has("reproduce_selected"), "recorded context exposes placement")
	_expect(actions.has("next_blueprint"), "recorded context exposes blueprint cycling")
	_expect(not actions.has("advanced_placement"), "recorded context no longer exposes a private placement mode")

	var before_blueprint: String = RecordedCatalog.get_selected_blueprint_id()
	menu.call("select_action_by_id", "next_blueprint")
	_expect(bool(menu.call("commit_selected_action")), "Next Object commits through the shared menu")
	_expect(bool(menu.call("is_context_open")), "blueprint cycling refreshes without closing the context")
	_expect(RecordedCatalog.get_selected_blueprint_id() != before_blueprint, "blueprint cycling changes the prepared object")

	menu.call("select_action_by_id", "reproduce_selected")
	_expect(bool(menu.call("commit_selected_action")), "recorded object hands off to shared placement")
	_expect(placement.is_placement_active(), "shared placement becomes active")
	_expect(placement.get_placement_id() == "recorded_object", "recorded placement has the correct shared id")
	_expect(recorded_manager.placement_active, "recorded manager supplies the live preview")
	_expect(not recorded_manager.controller_controls_enabled, "legacy recorded controller input stays disabled")
	_expect(not recorded_manager.keyboard_controls_enabled, "legacy recorded keyboard input stays disabled")
	_expect(action_state.is_manipulating, "shared placement locks ordinary actions")
	_expect(bool(player.get_meta("shared_placement_active", false)), "shared placement publishes movement lock state")

	var placement_blueprint: String = RecordedCatalog.get_selected_blueprint_id()
	_expect(placement.cycle_variant(1), "D-pad variant action cycles recorded objects")
	_expect(RecordedCatalog.get_selected_blueprint_id() != placement_blueprint, "recorded placement variant changes")
	var depth_before: float = recorded_manager.placement_depth_offset
	_expect(placement.adjust_depth(1), "shared depth adjustment reaches the recorded provider")
	_expect(recorded_manager.placement_depth_offset > depth_before, "recorded preview moves farther")
	var rotation_before: float = recorded_manager.placement_yaw_degrees
	_expect(placement.rotate_preview(1), "shared rotation reaches the recorded provider")
	_expect(recorded_manager.placement_yaw_degrees != rotation_before, "recorded preview rotates")
	_expect(placement.confirm_at(Vector3(5.0, 0.0, 0.0)), "shared placement reproduces the selected object")
	_expect(recorded_manager.get_active_count() == 1, "recorded object becomes active")
	_expect(not placement.is_placement_active(), "recorded placement exits after confirmation")
	_expect(not action_state.is_manipulating, "ordinary actions return after recorded placement")
	_expect(not bool(player.get_meta("shared_placement_active", false)), "movement lock clears after recorded placement")
	await get_tree().process_frame

	opened = router.call("try_open_context", player, RecordedAbility) as Dictionary
	_expect(bool(opened.get("success", false)), "Recorded Object reopens for active-object management")
	actions = _string_array(menu.call("get_available_action_ids"))
	_expect(actions.has("recall_last"), "active recorded context exposes Recall Last")
	menu.call("select_action_by_id", "recall_last")
	_expect(bool(menu.call("commit_selected_action")), "Recall Last commits")
	_expect(recorded_manager.get_active_count() == 0, "Recall Last removes the active recorded object")
	await get_tree().process_frame


func _test_artificer_assembly_context() -> void:
	PartCatalog.select_part("frame_block")
	var opened: Dictionary = router.call(
		"try_open_context",
		player,
		AssemblyAbility
	) as Dictionary
	_expect(bool(opened.get("success", false)), "Artificer Assembly opens the shared context")
	var actions: Array[String] = _string_array(menu.call("get_available_action_ids"))
	_expect(actions.has("place_part"), "assembly context exposes part placement")
	_expect(actions.has("next_part"), "assembly context exposes part cycling")
	_expect(not actions.has("advanced_assembly"), "assembly no longer exposes a private placement mode")

	menu.call("select_action_by_id", "place_part")
	_expect(bool(menu.call("commit_selected_action")), "prepared part enters shared placement")
	_expect(placement.get_placement_id() == "artificer_part", "assembly uses the shared part placement id")
	_expect(artificer_manager.mode == ArtificerConstructionManager.MODE_ASSEMBLY, "Artificer manager supplies the assembly preview")
	_expect(not artificer_manager.keyboard_controls_enabled, "legacy Artificer keyboard input stays disabled")

	var first_part_id: String = PartCatalog.get_selected_part_id()
	var first_size: Vector3 = PartCatalog.get_part_size(first_part_id)
	_expect(
		placement.confirm_at(Vector3(-4.0, first_size.y * 0.5, 3.0)),
		"first part attaches through shared placement"
	)
	_expect(placement.is_placement_active(), "assembly placement remains active after attaching a part")
	_expect(artificer_manager.draft_parts.size() == 1, "first part creates an Artificer draft")

	var before_part: String = PartCatalog.get_selected_part_id()
	_expect(placement.cycle_variant(1), "D-pad variant action cycles engineering parts")
	var second_part_id: String = PartCatalog.get_selected_part_id()
	_expect(second_part_id != before_part, "assembly variant changes the prepared part")
	var second_size: Vector3 = PartCatalog.get_part_size(second_part_id)
	_expect(
		placement.confirm_at(
			Vector3(-4.0, maxf(second_size.y * 0.5, 0.5), 4.5)
		),
		"second connected part attaches through shared placement"
	)
	_expect(artificer_manager.draft_parts.size() == 2, "draft contains two connected parts")
	_expect(placement.cancel_placement(), "B-style cancellation exits continuous assembly")
	_expect(not placement.is_placement_active(), "assembly placement closes on cancel")
	_expect(artificer_manager.mode == ArtificerConstructionManager.MODE_NONE, "Artificer preview mode cleans up on cancel")
	await get_tree().process_frame

	opened = router.call("try_open_context", player, AssemblyAbility) as Dictionary
	_expect(bool(opened.get("success", false)), "Assembly reopens for draft finalization")
	actions = _string_array(menu.call("get_available_action_ids"))
	_expect(actions.has("undo_part"), "draft context exposes Undo Last Part")
	_expect(actions.has("clear_draft"), "draft context exposes Clear Draft")
	_expect(actions.has("finalize_blueprint"), "two-part draft exposes Save Blueprint")
	menu.call("select_action_by_id", "finalize_blueprint")
	_expect(bool(menu.call("commit_selected_action")), "Save Blueprint commits through the shared context")
	_expect(artificer_manager.draft_parts.is_empty(), "saving clears the working draft")
	_expect(BuildCatalog.is_custom_build("custom_1"), "assembly saves the prepared custom blueprint slot")
	await get_tree().process_frame


func _test_deploy_context() -> void:
	var saved_builds: Array[String] = BuildCatalog.get_saved_build_ids()
	_expect(saved_builds.size() >= 2, "deploy test has starter and custom blueprints")
	var opened: Dictionary = router.call(
		"try_open_context",
		player,
		DeployAbility
	) as Dictionary
	_expect(bool(opened.get("success", false)), "Deploy Contraption opens the shared context")
	var actions: Array[String] = _string_array(menu.call("get_available_action_ids"))
	_expect(actions.has("deploy_selected"), "deploy context exposes placement")
	_expect(actions.has("next_build"), "deploy context exposes blueprint cycling")
	_expect(not actions.has("advanced_deploy"), "deploy no longer exposes a private placement mode")

	menu.call("select_action_by_id", "deploy_selected")
	_expect(bool(menu.call("commit_selected_action")), "prepared contraption enters shared placement")
	_expect(placement.get_placement_id() == "artificer_deploy", "deploy uses the shared contraption placement id")
	_expect(artificer_manager.mode == ArtificerConstructionManager.MODE_DEPLOY, "Artificer manager supplies the deployment preview")

	var before_build: String = BuildCatalog.get_selected_build_id()
	_expect(placement.cycle_variant(1), "D-pad variant action cycles saved contraptions")
	_expect(BuildCatalog.get_selected_build_id() != before_build, "deployment variant changes the prepared blueprint")
	var depth_before: float = artificer_manager.placement_depth_offset
	_expect(placement.adjust_depth(1), "shared depth adjustment reaches deployment")
	_expect(artificer_manager.placement_depth_offset > depth_before, "deployment preview moves farther")
	_expect(placement.rotate_preview(1), "shared rotation reaches deployment")
	_expect(
		placement.confirm_at(Vector3(6.0, 0.0, 6.0)),
		"shared placement deploys the contraption"
	)
	_expect(artificer_manager.get_active_count() == 1, "deployed contraption becomes active")
	_expect(not placement.is_placement_active(), "deployment exits after confirmation")
	await get_tree().process_frame

	opened = router.call("try_open_context", player, DeployAbility) as Dictionary
	_expect(bool(opened.get("success", false)), "Deploy reopens for active-contraption management")
	actions = _string_array(menu.call("get_available_action_ids"))
	_expect(actions.has("recall_contraption"), "active deploy context exposes Recall Last")
	menu.call("select_action_by_id", "recall_contraption")
	_expect(bool(menu.call("commit_selected_action")), "contraption Recall Last commits")
	_expect(artificer_manager.get_active_count() == 0, "Recall Last removes the active contraption")
	await get_tree().process_frame

	var placement_debug: Dictionary = placement.get_debug_data()
	_expect(int(placement_debug.get("begin_count", 0)) == 3, "all three placement families used one controller")
	_expect(int(placement_debug.get("variant_cycle_count", 0)) >= 3, "one variant control served every provider")
	if control_router != null and control_router.has_method("get_input_mode_debug_data"):
		var input_debug: Dictionary = control_router.call("get_input_mode_debug_data")
		_expect(not bool(input_debug.get("shared_placement", true)), "control router releases shared placement ownership")


func _prepare_test_state() -> void:
	HitStop.force_release()
	Engine.time_scale = 1.0
	for blueprint_id: String in RecordedCatalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(RecordedCatalog.get_item_id(blueprint_id))
	GameState.story_flags.erase(RecordedCatalog.SELECTED_BLUEPRINT_FLAG)
	for build_id: String in BuildCatalog.BUILD_ORDER:
		GameState.inventory.erase(BuildCatalog.get_item_id(build_id))
	GameState.story_flags.erase(BuildCatalog.SELECTED_BUILD_FLAG)
	GameState.story_flags.erase(BuildCatalog.SELECTED_CUSTOM_SLOT_FLAG)
	GameState.story_flags.erase(BuildCatalog.CUSTOM_BLUEPRINTS_FLAG)
	for slot_id: String in BuildCatalog.CUSTOM_SLOT_ORDER:
		GameState.story_flags.erase(BuildCatalog.get_custom_slot_flag(slot_id))
	for part_id: String in PartCatalog.PART_ORDER:
		GameState.story_flags.erase(PartCatalog.UNLOCK_PREFIX + part_id)
	GameState.story_flags.erase(PartCatalog.SELECTED_PART_FLAG)

	PartCatalog.unlock_all_for_debug()
	PartCatalog.select_part("frame_block")
	for blueprint_id: String in RecordedCatalog.BLUEPRINT_ORDER:
		RecordedCatalog.record_blueprint(blueprint_id)
	RecordedCatalog.select_blueprint("crate")
	var starter_result: Dictionary = BuildCatalog.save_build("bridge_frame")
	_expect(bool(starter_result.get("ok", false)), "starter bridge blueprint is available for deploy cycling")
	BuildCatalog.select_custom_slot("custom_1")
	GameState.set_stat("mana", 99)


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)
	old_time_scale = Engine.time_scale


func _cleanup_and_finish() -> void:
	if placement != null and is_instance_valid(placement):
		placement.cancel_placement()
	if menu != null and is_instance_valid(menu) and menu.has_method("cancel_context"):
		menu.call("cancel_context")
	if recorded_manager != null and is_instance_valid(recorded_manager):
		recorded_manager.cancel_placement()
		recorded_manager.clear_spawned_objects()
	if artificer_manager != null and is_instance_valid(artificer_manager):
		artificer_manager.cancel_mode()
		artificer_manager.clear_draft()
		artificer_manager.clear_active_contraptions()
	if player != null and is_instance_valid(player):
		player.queue_free()
	if floor != null and is_instance_valid(floor):
		floor.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)
	HitStop.force_release()
	Engine.time_scale = old_time_scale
	await get_tree().process_frame
	_finish()


func _make_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "PersistentContextTestFloor"
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 0.5, 40.0)
	collision.shape = shape
	collision.position.y = -0.25
	body.add_child(collision)
	return body


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			result.append(str(raw))
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PERSISTENT_ABILITY_CONTEXT_PROVIDERS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PERSISTENT_ABILITY_CONTEXT_PROVIDERS_SMOKE_TEST: " + failure)
	get_tree().quit(1)
