extends Node

const FullMenuShellScript = preload(
	"res://scripts/ui/full_menu_shell_magic_v3.gd"
)
const PatronCatalogScript = preload(
	"res://scripts/divine/divine_patron_catalog.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var shell: FullMenuShellMagicV3 = FullMenuShellScript.new()
	add_child(shell)
	shell.show_menu(_make_menu_data())
	shell.select_tab(shell.get_tab_index("magic"))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(PatronCatalogScript.validate_catalog().is_empty(), "sixteen-patron catalog validates")
	assert_equal(PatronCatalogScript.PATRON_ORDER.size(), 16, "catalog contains sixteen patrons")
	assert_equal(shell.selectable_actions.size(), 26, "Magic overview adds two divine gates")
	var debug_data: Dictionary = shell.get_magic_debug_data()
	assert_true(bool(debug_data.get("divine_gates_present", false)), "divine gates are visible beneath traditions")
	assert_equal(int(debug_data.get("divine_gate_count", 0)), 2, "Patrons and Incarnations are separate gates")
	assert_equal(int(debug_data.get("patron_count", 0)), 16, "Magic reports sixteen patrons")
	assert_true(bool(debug_data.get("scroll_disabled", false)), "divine Magic overview remains scroll-free")

	# Patrons are the first divine gate after sixteen elements and eight traditions.
	shell.activate_action(shell.selectable_actions[24] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "patrons", "Patrons opens in the shared Magic workspace")
	assert_equal(shell.selectable_actions.size(), 42, "patron roster adds a 4x4 grid")
	assert_true(shell.find_child("MagicPatronGrid", true, false) != null, "patron grid exists")
	var tirisi_action: Dictionary = shell.selectable_actions[26] as Dictionary
	assert_equal(str(tirisi_action.get("patron_id", "")), "tirisi", "Water patron occupies the first roster slot")
	shell.activate_action(tirisi_action)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "patron", "patron record opens one level deeper")
	assert_equal(shell.selected_patron_id, "tirisi", "Tirisi patron identity is stable")
	assert_true(shell.find_child("MagicElementGrid", true, false) != null, "element atlas remains beside patron details")

	var back_event: InputEventJoypadButton = InputEventJoypadButton.new()
	back_event.button_index = JOY_BUTTON_B
	back_event.pressed = true
	assert_true(shell.handle_menu_input(back_event), "patron detail consumes Back")
	assert_equal(shell.magic_page, "patrons", "Back returns to patron roster")
	assert_true(shell.handle_menu_input(back_event), "patron roster consumes Back")
	assert_equal(shell.magic_page, "overview", "second Back collapses Patrons")

	# Divine Incarnations are the second permanent gate.
	shell.activate_action(shell.selectable_actions[25] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "incarnations", "Incarnations opens in the shared workspace")
	assert_equal(shell.selectable_actions.size(), 42, "incarnation roster adds a 4x4 grid")
	assert_true(shell.find_child("MagicIncarnationGrid", true, false) != null, "incarnation grid exists")
	var ruvia_action: Dictionary = shell.selectable_actions[28] as Dictionary
	assert_equal(str(ruvia_action.get("patron_id", "")), "ruvia", "Ruvia occupies the Fire incarnation slot")
	shell.activate_action(ruvia_action)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "incarnation", "Ruvia incarnation record opens")
	assert_equal(shell.selected_patron_id, "ruvia", "Ruvia incarnation identity is stable")
	assert_true(bool(shell.get_magic_debug_data().get("scroll_disabled", false)), "incarnation detail remains scroll-free")

	shell.hide_menu()
	shell.queue_free()
	if failures.is_empty():
		print("FULL_MENU_MAGIC_DIVINE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FULL_MENU_MAGIC_DIVINE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _make_menu_data() -> Dictionary:
	var sections: Array[Dictionary] = []
	for element_id: String in FullMenuShellScript.ELEMENT_ORDER:
		sections.append({
			"element": element_id,
			"title": element_id.capitalize(),
			"spells": [],
		})
	return {
		"loadout_summary": {
			"learned_count": 0,
			"active_ring_count": 0,
		},
		"learned_spell_sections": sections,
		"equipped_spell_slots": [],
		"spellcasting_mastery": {
			"rows": [],
			"summary": {
				"initiated_count": 0,
				"tradition_count": 8,
				"mastered_count": 0,
			},
		},
		"familiar_mastery": {
			"rows": [],
			"summary": {},
			"equipped_species_id": "",
			"equipped_name": "None",
		},
	}


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
