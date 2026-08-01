extends Node

const ShellScript = preload(
	"res://scripts/ui/full_menu_shell_progression_v1.gd"
)
const ChallengeCatalogScript = preload(
	"res://scripts/progression/progression_challenge_catalog.gd"
)

var failures: Array[String] = []
var old_story_flags: Dictionary = {}
var old_unlocks: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	old_story_flags = GameState.story_flags.duplicate(true)
	old_unlocks = GameState.get_unlock_snapshot()
	_clear_test_progress()
	for failure: String in ChallengeCatalogScript.validate_catalog():
		failures.append("challenge catalog: " + failure)

	var tracker: Node = get_node_or_null(
		"/root/FullMenuDirector/ProgressionTracker"
	)
	assert_true(tracker != null, "FullMenuDirector owns the progression tracker")
	if tracker == null:
		_restore_state()
		_finish()
		return

	var shell: Control = ShellScript.new()
	add_child(shell)
	await get_tree().process_frame
	shell.call("show_menu", _make_menu_data())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_equal(shell.call("get_current_tab_id"), "loadout", "Grace opens as the first main tab")
	var zr := InputEventJoypadMotion.new()
	zr.axis = JOY_AXIS_TRIGGER_RIGHT
	zr.axis_value = 1.0
	shell.call("handle_menu_input", zr)
	assert_equal(shell.call("get_current_tab_id"), "magic", "ZR advances the main tab")
	zr.axis_value = 0.0
	shell.call("handle_menu_input", zr)
	var zl := InputEventJoypadMotion.new()
	zl.axis = JOY_AXIS_TRIGGER_LEFT
	zl.axis_value = 1.0
	shell.call("handle_menu_input", zl)
	assert_equal(shell.call("get_current_tab_id"), "loadout", "ZL returns to the previous main tab")
	zl.axis_value = 0.0
	shell.call("handle_menu_input", zl)

	var right_shoulder := InputEventJoypadButton.new()
	right_shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	right_shoulder.pressed = true
	shell.call("handle_menu_input", right_shoulder)
	assert_equal(shell.get("loadout_page"), "weapon_classes", "R opens the first Grace subtab")
	shell.call("handle_menu_input", right_shoulder)
	assert_equal(shell.get("loadout_page"), "wardrobe", "R advances to the next Grace subtab")
	var left_shoulder := InputEventJoypadButton.new()
	left_shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	left_shoulder.pressed = true
	shell.call("handle_menu_input", left_shoulder)
	assert_equal(shell.get("loadout_page"), "weapon_classes", "L returns to the previous Grace subtab")

	var hidden_rows: Array = shell.call("_get_journal_rows", "elements") as Array
	assert_true(_reaction_is_hidden(hidden_rows, "wet_conduction"), "undiscovered reactions are masked in the Journal")

	tracker.call("record_event", "reaction_triggered", "ignite_oil", {"amount": 1})
	for _index: int in range(3):
		tracker.call("record_event", "reaction_triggered", "wet_conduction", {"amount": 1})
	for _index: int in range(5):
		tracker.call("record_event", "reaction_triggered", "shatter", {"amount": 1})
	tracker.call("record_event", "recipe_discovered", "healing_potion", {})
	tracker.call("record_event", "recipe_discovered", "healing_potion", {})
	tracker.call("record_event", "recipe_discovered", "antidote", {})
	tracker.call("record_event", "recipe_discovered", "conductive_elixir", {})
	tracker.call("record_event", "species_rank", "gremlin", {"value": 3})

	assert_true(GameState.has_unlock("charged_firebolt"), "Ignite Oil unlocks Charged Firebolt")
	assert_true(GameState.has_unlock("chain_lightning"), "three Wet Conductions unlock Chain Lightning")
	assert_true(GameState.has_unlock("piercing_ice_lance"), "five Shatters unlock Piercing Ice Lance")
	assert_true(GameState.has_unlock("alchemy_recipe_insight"), "three unique recipes unlock Alchemy Insight")
	assert_true(GameState.has_unlock("gremlin_pounce"), "Gremlin rank three records Pounce")
	var challenge_rows: Array = tracker.call("get_challenge_rows") as Array
	assert_equal(challenge_rows.size(), 5, "the starter progression set exposes five challenges")
	assert_equal(_complete_count(challenge_rows), 5, "all five starter challenges can complete")
	var chemistry: Dictionary = tracker.call("get_challenge_progress", "kitchen_chemistry") as Dictionary
	assert_equal(chemistry.get("current"), 3, "duplicate potion discoveries do not inflate unique progress")

	var revealed_rows: Array = shell.call("_get_journal_rows", "elements") as Array
	assert_true(not _reaction_is_hidden(revealed_rows, "wet_conduction"), "performed reactions reveal their Journal equation")

	GameState.start_quest("backbone_story", {
		"title": "The Backbone Test",
		"quest_type": "story",
		"objective": "Follow the tracked objective.",
		"stages": ["Begin", "Finish"],
	})
	shell.set("selected_codex_category", "story")
	shell.set("selected_codex_record_id", "backbone_story")
	shell.call("activate_action", {
		"kind": "select_codex_record",
		"record_id": "backbone_story",
	})
	assert_equal(tracker.call("get_tracked_quest_id"), "backbone_story", "selecting an inspected quest tracks it")
	assert_equal(GameState.current_objective, "Follow the tracked objective.", "tracked quest controls the HUD objective")

	var footer: String = str(shell.call("get_footer_text"))
	assert_true(footer.contains("ZL/ZR: tabs"), "footer teaches main-tab triggers")
	assert_true(footer.contains("L/R: subtabs"), "footer teaches shoulder subtabs")
	var debug: Dictionary = shell.call("get_codex_debug_data") as Dictionary
	assert_true(bool(debug.get("hierarchical_shoulders", false)), "debug data reports hierarchical shoulder controls")

	shell.queue_free()
	_restore_state()
	_finish()


func _make_menu_data() -> Dictionary:
	return {
		"objective": "Test progression.",
		"stats": {},
		"stat_sections": [],
		"spells": [],
		"equipped_spell_slots": [],
		"learned_spell_sections": [],
		"loadout_summary": {},
		"weapon": {},
		"quick_item_slots": [],
		"inventory_items": [],
		"key_items": [],
		"spellcasting_mastery": {},
		"familiar_mastery": {},
	}


func _reaction_is_hidden(rows: Array, reaction_id: String) -> bool:
	var result_name: String = reaction_id.replace("_", " ").capitalize()
	for raw: Variant in rows:
		if not raw is Dictionary:
			continue
		for raw_line: Variant in (raw as Dictionary).get("reaction_lines", []):
			var line: String = str(raw_line)
			if line.contains("→ ???"):
				var original_result: String = result_name
				if original_result != "":
					return true
			if line.ends_with("→ " + result_name):
				return false
	return false


func _complete_count(rows: Array) -> int:
	var count: int = 0
	for raw: Variant in rows:
		if raw is Dictionary and bool((raw as Dictionary).get("complete", false)):
			count += 1
	return count


func _clear_test_progress() -> void:
	for raw_key: Variant in GameState.story_flags.keys():
		var key: String = str(raw_key)
		if key.begins_with("__progression__::"):
			GameState.story_flags.erase(raw_key)
	for reward_id: String in [
		"charged_firebolt",
		"chain_lightning",
		"piercing_ice_lance",
		"alchemy_recipe_insight",
		"gremlin_pounce",
	]:
		GameState.revoke_unlock(reward_id)
	GameState.reset_quest("backbone_story")


func _restore_state() -> void:
	GameState.story_flags = old_story_flags.duplicate(true)
	var current: Dictionary = GameState.get_unlock_snapshot()
	for raw_key: Variant in current.keys():
		GameState.revoke_unlock(str(raw_key))
	for raw_key: Variant in old_unlocks.keys():
		var value: Variant = old_unlocks[raw_key]
		GameState.grant_unlock(
			str(raw_key),
			(value as Dictionary).duplicate(true) if value is Dictionary else {}
		)
	GameState.reset_quest("backbone_story")


func _finish() -> void:
	if failures.is_empty():
		print("PROGRESSION_BACKBONE_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PROGRESSION_BACKBONE_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + " (expected " + str(expected) + ", got " + str(actual) + ")")
