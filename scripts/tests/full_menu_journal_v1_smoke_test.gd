extends Node

const JournalShellScript = preload(
	"res://scripts/ui/full_menu_shell_journal_v1.gd"
)
const JournalCatalogScript = preload(
	"res://scripts/journal/journal_record_catalog.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	for failure: String in JournalCatalogScript.validate_catalog():
		failures.append("catalog: " + failure)

	var old_healing_flag: bool = GameState.get_flag(
		"recipe_discovered_healing_potion"
	)
	GameState.set_flag("recipe_discovered_healing_potion", true)

	var shell: Control = JournalShellScript.new()
	add_child(shell)
	await get_tree().process_frame
	shell.set("selected_tab_index", int(shell.call("get_tab_index", "journal")))
	shell.call("show_menu", _make_menu_data())
	await get_tree().process_frame
	await get_tree().process_frame

	var debug_data: Dictionary = shell.call("get_journal_debug_data") as Dictionary
	assert_equal(debug_data.get("category_count"), 7, "Journal exposes seven permanent shelves")
	assert_equal(debug_data.get("potion_count"), 5, "Potion shelf exposes five authored formulas")
	assert_true(int(debug_data.get("fauna_count", 0)) >= 2, "Fauna includes current species records")
	assert_true(int(debug_data.get("flora_count", 0)) >= 2, "Flora includes starter botanical records")
	assert_equal(debug_data.get("note_count"), 5, "Field Notes reserves five record families")
	assert_true(bool(debug_data.get("category_strip_present", false)), "Journal category strip is present")
	assert_true(bool(debug_data.get("workspace_present", false)), "Journal shared workspace is present")
	assert_true(bool(debug_data.get("scroll_disabled", false)), "Journal is scroll-free")
	assert_equal(int(shell.call("get_tab_index", "relics")), 0, "Relics remains folded into Items")

	shell.call("activate_action", {
		"kind": "toggle_journal_category",
		"category_id": "potions",
	})
	await get_tree().process_frame
	debug_data = shell.call("get_journal_debug_data") as Dictionary
	assert_equal(debug_data.get("selected_category"), "potions", "Potion shelf expands")
	var potion_rows: Array = shell.call("_get_journal_rows", "potions") as Array
	assert_equal(potion_rows.size(), 5, "Potion detail rows remain complete")
	assert_true(_row_is_learned(potion_rows, "healing_potion"), "discovered potion flag appears in Journal")
	assert_true(shell.find_child("JournalRecordGrid", true, false) != null, "Potion record grid renders")
	assert_true(shell.find_child("JournalDetailPanel", true, false) != null, "Potion detail panel renders")

	shell.call("activate_action", {
		"kind": "toggle_journal_category",
		"category_id": "blueprints",
	})
	await get_tree().process_frame
	var blueprint_rows: Array = shell.call("_get_journal_rows", "blueprints") as Array
	assert_equal(blueprint_rows.size(), 2, "Object and Build records share the Blueprint shelf")
	assert_true(_has_row(blueprint_rows, "noise_maker"), "Object blueprint is logged")
	assert_true(_has_row(blueprint_rows, "test_glider"), "Build blueprint is logged")

	for category_id: String in ["fauna", "flora", "notes"]:
		shell.call("activate_action", {
			"kind": "toggle_journal_category",
			"category_id": category_id,
		})
		await get_tree().process_frame
		debug_data = shell.call("get_journal_debug_data") as Dictionary
		assert_equal(
			debug_data.get("selected_category"),
			category_id,
			category_id.capitalize() + " shelf expands"
		)

	var nav_debug: Dictionary = shell.call("get_navigation_debug_data") as Dictionary
	assert_true(
		bool(nav_debug.get("navigation_graph_synchronized", false)),
		"Journal inherits safe live-control navigation"
	)

	GameState.set_flag("recipe_discovered_healing_potion", old_healing_flag)
	shell.queue_free()
	_finish()


func _make_menu_data() -> Dictionary:
	return {
		"objective": "Test the learned-record Journal.",
		"inventory_items": [
			{
				"id": "noise_maker",
				"name": "Noise Maker",
				"icon": "♪",
				"description": "A recorded distraction object.",
				"count": 1,
				"tags": ["object_blueprint", "deployable_object"],
			},
			{
				"id": "test_glider",
				"name": "Test Glider",
				"icon": "⚙",
				"description": "A saved engineering construction.",
				"count": 1,
				"tags": ["build", "engineering_blueprint"],
			},
		],
		"key_items": [
			{
				"id": "trial_proof",
				"display_name": "Trial Proof",
				"description": "Evidence recorded by the Journal.",
			},
		],
		"equipped_spell_slots": [],
		"quick_item_slots": [],
		"learned_spell_sections": [],
		"inventory_summary": {},
		"loadout_summary": {},
		"spellcasting_mastery": {},
		"familiar_mastery": {},
	}


func _has_row(rows: Array, record_id: String) -> bool:
	for value: Variant in rows:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == record_id:
			return true
	return false


func _row_is_learned(rows: Array, record_id: String) -> bool:
	for value: Variant in rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if str(row.get("id", "")) == record_id:
			return bool(row.get("learned", false))
	return false


func _finish() -> void:
	if failures.is_empty():
		print("FULL_MENU_JOURNAL_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FULL_MENU_JOURNAL_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
