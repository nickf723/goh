extends Node

const CodexShellScript = preload(
	"res://scripts/ui/full_menu_shell_codex_v1.gd"
)
const CodexCatalogScript = preload(
	"res://scripts/codex/codex_progress_catalog.gd"
)
const ElementJournalCatalogScript = preload(
	"res://scripts/journal/element_journal_catalog.gd"
)

const STORY_QUEST_ID: String = "codex_test_story_quest"
const SIDE_QUEST_ID: String = "codex_test_side_quest"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	for failure: String in CodexCatalogScript.validate_catalog():
		failures.append("codex catalog: " + failure)
	for failure: String in ElementJournalCatalogScript.validate_catalog():
		failures.append("element journal: " + failure)

	GameState.reset_quest(STORY_QUEST_ID)
	GameState.reset_quest(SIDE_QUEST_ID)
	GameState.start_quest(STORY_QUEST_ID, {
		"title": "Follow the Scarlet Road",
		"description": "A test main-story path.",
		"quest_type": "story",
		"objective": "Reach the next story marker.",
		"stages": ["Find the road", "Cross the pass", "Reach the shrine"],
		"stage": 1,
	})
	GameState.start_quest(SIDE_QUEST_ID, {
		"title": "A Cartographer's Favor",
		"description": "A test optional path.",
		"quest_type": "side",
		"objective": "Return the missing map.",
		"stages": ["Accept the favor", "Recover the map"],
		"stage": 0,
	})

	var shell: Control = CodexShellScript.new()
	add_child(shell)
	await get_tree().process_frame
	shell.set("selected_tab_index", int(shell.call("get_tab_index", "codex")))
	shell.call("show_menu", _make_menu_data())
	await get_tree().process_frame
	await get_tree().process_frame

	var codex_debug: Dictionary = shell.call("get_codex_debug_data") as Dictionary
	assert_equal(codex_debug.get("category_count"), 5, "Codex exposes five pursuit categories")
	assert_true(int(codex_debug.get("story_count", 0)) >= 1, "Story quest ledger reads active story quests")
	assert_true(int(codex_debug.get("side_count", 0)) >= 1, "Side quest ledger reads active side quests")
	assert_true(int(codex_debug.get("challenge_count", 0)) >= 6, "Unlock challenges populate from the unlock catalog")
	assert_equal(codex_debug.get("achievement_count"), 32, "Achievement ledger exposes all spellcasting milestones")
	assert_equal(codex_debug.get("completion_count"), 5, "Completion dashboard exposes five aggregate records")
	assert_true(bool(codex_debug.get("category_strip_present", false)), "Codex pursuit strip is present")
	assert_true(bool(codex_debug.get("workspace_present", false)), "Codex shared workspace is present")
	assert_true(bool(codex_debug.get("scroll_disabled", false)), "Codex is scroll-free")

	shell.call("activate_action", {"kind": "toggle_codex_category", "category_id": "achievements"})
	await get_tree().process_frame
	assert_true(shell.find_child("CodexRecordGrid", true, false) != null, "Achievement grid renders")
	assert_true(shell.find_child("CodexDetailPanel", true, false) != null, "Achievement detail panel renders")
	assert_true(shell.find_child("CodexProgressBar", true, false) != null, "Achievement detail shows progress")
	shell.call("activate_action", {"kind": "codex_page_delta", "delta": 1})
	await get_tree().process_frame
	codex_debug = shell.call("get_codex_debug_data") as Dictionary
	assert_equal(codex_debug.get("record_page"), 1, "Large achievement ledger pages without scrolling")

	shell.call("activate_action", {"kind": "toggle_codex_category", "category_id": "completion"})
	await get_tree().process_frame
	assert_true(shell.find_child("CodexProgressBar", true, false) != null, "Completion dashboard uses the same progress contract")

	shell.call("select_tab", int(shell.call("get_tab_index", "journal")))
	await get_tree().process_frame
	shell.call("activate_action", {"kind": "toggle_journal_category", "category_id": "elements"})
	await get_tree().process_frame
	var journal_debug: Dictionary = shell.call("get_journal_debug_data") as Dictionary
	assert_equal(journal_debug.get("category_count"), 8, "Journal adds an Elements shelf")
	assert_equal(journal_debug.get("element_count"), 16, "Element journal uses the complete 4 by 4 atlas")
	assert_true(int(journal_debug.get("reaction_count", 0)) >= 8, "All authored reactions moved into Journal")
	assert_true(bool(journal_debug.get("element_grid_present", false)), "Element 4 by 4 grid renders")
	var element_rows: Array = shell.call("_get_journal_rows", "elements") as Array
	var fire_row: Dictionary = _find_row(element_rows, "fire")
	assert_equal(fire_row.get("spell_count"), 1, "Element records include learned attacks")
	assert_true(int(fire_row.get("reaction_count", 0)) > 0, "Fire record includes relevant reactions")
	assert_true((fire_row.get("details", []) as Array).size() >= 5, "Element detail includes verbs properties attacks and reactions")

	var nav_debug: Dictionary = shell.call("get_navigation_debug_data") as Dictionary
	assert_true(bool(nav_debug.get("navigation_graph_synchronized", false)), "Codex and Journal retain safe rebuilt navigation")

	GameState.reset_quest(STORY_QUEST_ID)
	GameState.reset_quest(SIDE_QUEST_ID)
	shell.queue_free()
	_finish()


func _make_menu_data() -> Dictionary:
	return {
		"objective": "Test the pursuit Codex.",
		"inventory_items": [],
		"key_items": [],
		"equipped_spell_slots": [],
		"quick_item_slots": [],
		"learned_spell_sections": [
			{
				"element": "fire",
				"title": "Fire",
				"spells": [
					{
						"id": "firebolt",
						"spell_id": "firebolt",
						"name": "Firebolt",
						"element": "fire",
						"delivery_type": "projectile",
						"targeting_style": "aimed",
						"tags": ["damage", "ignite", "projectile"],
					},
				],
			},
		],
		"inventory_summary": {},
		"loadout_summary": {},
		"spellcasting_mastery": {},
		"familiar_mastery": {},
	}


func _find_row(rows: Array, record_id: String) -> Dictionary:
	for value: Variant in rows:
		if value is Dictionary and str((value as Dictionary).get("id", "")) == record_id:
			return value as Dictionary
	return {}


func _finish() -> void:
	if failures.is_empty():
		print("FULL_MENU_CODEX_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FULL_MENU_CODEX_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + " (expected " + str(expected) + ", got " + str(actual) + ")")
