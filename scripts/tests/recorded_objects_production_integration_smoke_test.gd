extends Node

const FieldScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_ruined_village_field_progression_v1.tscn"
)
const ShellScript = preload(
	"res://scripts/ui/full_menu_shell_recorded_objects_v1.gd"
)
const Catalog = preload("res://scripts/objects/recorded_object_catalog.gd")

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var field: Node3D
var requested_blueprint_id: String = ""


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_recorded_object_state()
	field = FieldScene.instantiate() as Node3D
	add_child(field)
	for _index: int in range(28):
		await get_tree().process_frame
	await get_tree().physics_frame

	var player: Node3D = field.get_node_or_null("Player") as Node3D
	var manager: RecordedObjectManager = (
		player.get_node_or_null("RecordedObjectManager") as RecordedObjectManager
		if player != null
		else null
	)
	var hud: CanvasLayer = (
		player.get_node_or_null("RecordedObjectStatusHUD") as CanvasLayer
		if player != null
		else null
	)
	assert_true(player != null, "field route contains Grace")
	assert_true(manager != null, "production runtime attaches a recorded object manager")
	assert_true(hud != null, "production runtime attaches a recorded object HUD")
	assert_equal(
		get_tree().get_nodes_in_group("recorded_object_manager").size(),
		1,
		"field route owns exactly one recorded object manager"
	)
	assert_equal(
		get_tree().get_nodes_in_group("recordable_world_object").size(),
		2,
		"field route contains two natural blueprint sources"
	)
	if player == null or manager == null:
		_restore_state()
		_finish()
		return

	var field_debug: Dictionary = field.call(
		"get_field_progression_debug_data"
	) as Dictionary
	assert_true(bool(field_debug.get("crate_source", false)), "garden crate source is registered")
	assert_true(bool(field_debug.get("platform_source", false)), "ravine platform source is registered")

	var crate_source: Node = field.get_node_or_null(
		"FieldProgression/RecordedObjectSources/HerbalistSupplyCrate"
	)
	assert_true(crate_source != null, "herbalist crate source exists")
	if crate_source != null:
		var result: Dictionary = crate_source.call("interact") as Dictionary
		assert_true(
			str(result.get("message", "")).contains("Blueprint recorded"),
			"studying the field crate records its blueprint"
		)
	assert_true(Catalog.is_recorded("crate"), "crate blueprint persists in inventory")
	assert_equal(
		Catalog.get_selected_blueprint_id(),
		"crate",
		"newly recorded crate becomes selected"
	)
	await get_tree().process_frame
	var hud_debug: Dictionary = hud.call("get_debug_data") as Dictionary if hud != null else {}
	assert_true(bool(hud_debug.get("manager_ready", false)), "recorded object HUD binds the manager")
	assert_true(bool(hud_debug.get("visible", false)), "recorded object HUD appears after discovery")

	var shell: FullMenuShellRecordedObjectsV1 = ShellScript.new()
	add_child(shell)
	shell.recorded_object_prepare_requested.connect(_on_prepare_requested)
	shell.show_menu(_make_menu_data())
	shell.select_tab(shell.get_tab_index("items"))
	await get_tree().process_frame
	var object_category_action: Dictionary = shell.selectable_actions[4] as Dictionary
	shell.activate_action(object_category_action)
	await get_tree().process_frame
	assert_equal(shell.selected_item_category, "objects", "Items Objects category opens")
	var crate_action: Dictionary = _find_item_action(
		shell.selectable_actions,
		Catalog.get_item_id("crate")
	)
	assert_true(not crate_action.is_empty(), "crate blueprint appears under Items Objects")
	if not crate_action.is_empty():
		shell.activate_action(crate_action)
		await get_tree().process_frame
		assert_equal(requested_blueprint_id, "", "first confirm only prepares the blueprint")
		assert_equal(
			shell.armed_recorded_object_item_id,
			Catalog.get_item_id("crate"),
			"first confirm arms the selected object"
		)
		shell.activate_action(crate_action)
		assert_equal(requested_blueprint_id, "crate", "second confirm requests gameplay placement")
	var menu_debug: Dictionary = shell.get_recorded_object_menu_debug_data()
	assert_equal(menu_debug.get("selected_blueprint_id"), "crate", "menu and runtime share selection")
	shell.hide_menu()
	shell.queue_free()

	var director: Node = get_node_or_null("/root/FullMenuDirector")
	assert_true(director != null, "FullMenuDirector is available")
	if director != null:
		director.call("_on_recorded_object_prepare_requested", "crate")
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(manager.placement_active, "menu request enters production placement mode")
		assert_equal(
			str(manager.get_debug_data().get("selected_blueprint", "")),
			"crate",
			"placement manager receives the menu blueprint"
		)
		manager.cancel_placement()

	var platform_source: Node = field.get_node_or_null(
		"FieldProgression/RecordedObjectSources/RavineScaffoldPlatform"
	)
	assert_true(platform_source != null, "ravine platform source exists")
	if platform_source != null:
		platform_source.call("interact")
	assert_true(Catalog.is_recorded("platform"), "platform blueprint can be learned in the field")
	assert_equal(
		ItemInventoryCategoryCatalog.classify_inventory_row(
			_find_inventory_row(Catalog.get_item_id("platform"))
		),
		"objects",
		"field-recorded platform remains in Items Objects"
	)

	_restore_state()
	_finish()


func _make_menu_data() -> Dictionary:
	return {
		"inventory_items": GameState.get_inventory_rows(),
		"key_items": [],
		"loadout_summary": {},
		"learned_spell_sections": [],
		"equipped_spell_slots": [],
		"spellcasting_mastery": {"rows": [], "summary": {}},
		"familiar_mastery": {"rows": [], "summary": {}},
		"recorded_objects": {
			"selected_blueprint_id": Catalog.get_selected_blueprint_id(),
			"rows": Catalog.get_recorded_rows(),
			"manager_available": true,
		},
	}


func _find_item_action(actions: Array, item_id: String) -> Dictionary:
	for raw_action: Variant in actions:
		if not raw_action is Dictionary:
			continue
		var action: Dictionary = raw_action as Dictionary
		if (
			str(action.get("kind", "")) == "select_inventory_record"
			and str(action.get("item_id", "")) == item_id
		):
			return action
	return {}


func _find_inventory_row(item_id: String) -> Dictionary:
	for row: Dictionary in GameState.get_inventory_rows():
		if str(row.get("id", "")) == item_id:
			return row
	return {}


func _on_prepare_requested(blueprint_id: String) -> void:
	requested_blueprint_id = blueprint_id


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)


func _clear_recorded_object_state() -> void:
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(Catalog.get_item_id(blueprint_id))
		GameState.story_flags.erase("recorded_world_object_" + blueprint_id)
	GameState.story_flags.erase(Catalog.SELECTED_BLUEPRINT_FLAG)


func _restore_state() -> void:
	for manager_node: Node in get_tree().get_nodes_in_group("recorded_object_manager"):
		if manager_node != null and manager_node.has_method("clear_spawned_objects"):
			manager_node.call("clear_spawned_objects")
	if field != null and is_instance_valid(field):
		field.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("RECORDED_OBJECTS_PRODUCTION_INTEGRATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RECORDED_OBJECTS_PRODUCTION_INTEGRATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
