extends Node

const FullMenuShellScript = preload(
	"res://scripts/ui/full_menu_shell_loadout_v1.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var shell: FullMenuShellLoadoutV1 = FullMenuShellScript.new()
	add_child(shell)
	shell.show_menu(_make_menu_data())

	assert_true(shell.is_open(), "shell opens")
	assert_equal(shell.loadout_page, "overview", "Grace begins at the combined loadout overview")
	assert_equal(shell.get_current_tab_id(), "loadout", "Grace remains the first tab id")
	assert_equal(shell.MENU_TAB_DEFS.size(), 7, "Grace and Loadout share one top-level tab")
	assert_equal(str(shell.MENU_TAB_DEFS[0].get("title", "")), "Grace", "first tab is visibly Grace")
	assert_equal(shell.get_tab_index("grace"), 0, "removed Grace id falls back safely")
	assert_equal(shell.selectable_actions.size(), 17, "Grace page exposes four equipment slots, three field settings, and ten spells")
	assert_true(str(shell.content_title_label.text).contains("Grace"), "Grace owns the page title")

	for action_value: Variant in shell.selectable_actions:
		if action_value is Dictionary:
			assert_true(
				str((action_value as Dictionary).get("page", "")) != "familiar",
				"Familiar customization is not duplicated in Grace"
			)

	var first_spell_action: Dictionary = shell.selectable_actions[7] as Dictionary
	var last_spell_action: Dictionary = shell.selectable_actions[16] as Dictionary
	assert_equal(str(first_spell_action.get("kind", "")), "choose_spell_slot", "spell ribbon begins after field configuration")
	assert_equal(int(first_spell_action.get("slot", -1)), 0, "spell ribbon begins with slot one")
	assert_equal(int(last_spell_action.get("slot", -1)), 9, "spell ribbon ends with slot ten")
	assert_equal(int(first_spell_action.get("nav_row", -1)), 3, "spell ribbon occupies one navigation row")
	assert_equal(int(last_spell_action.get("nav_row", -1)), 3, "all ten spell slots share one row")

	shell.activate_action(shell.selectable_actions[4] as Dictionary)
	assert_equal(shell.loadout_page, "infusion", "Weapon Infusion opens as a nested Grace page")
	assert_true(str(shell.content_title_label.text).contains("Weapon Infusion"), "nested page receives breadcrumb title")

	var back_event: InputEventJoypadButton = InputEventJoypadButton.new()
	back_event.button_index = JOY_BUTTON_B
	back_event.pressed = true
	assert_true(shell.handle_menu_input(back_event), "nested page consumes controller Back")
	assert_equal(shell.loadout_page, "overview", "controller Back returns to Grace")
	assert_equal(shell.selected_action_index, 4, "Back restores the originating field setting")

	shell.select_tab(shell.get_tab_index("magic"))
	var left_shoulder: InputEventJoypadButton = InputEventJoypadButton.new()
	left_shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	left_shoulder.pressed = true
	assert_true(shell.handle_menu_input(left_shoulder), "left shoulder is consumed inside the menu")
	assert_equal(shell.get_current_tab_id(), "loadout", "left shoulder moves one tab left")

	assert_equal(
		shell.get_menu_confirm_button_for_name("Nintendo Switch Pro Controller"),
		JOY_BUTTON_B,
		"Nintendo physical A maps to menu confirm"
	)
	assert_equal(
		shell.get_menu_cancel_button_for_name("Nintendo Switch Pro Controller"),
		JOY_BUTTON_A,
		"Nintendo physical B maps to menu cancel"
	)
	assert_equal(
		shell.get_menu_confirm_button_for_name("Xbox Wireless Controller"),
		JOY_BUTTON_A,
		"Xbox A confirms"
	)
	assert_equal(
		shell.get_menu_cancel_button_for_name("Xbox Wireless Controller"),
		JOY_BUTTON_B,
		"Xbox B cancels"
	)

	var root_back: InputEventJoypadButton = InputEventJoypadButton.new()
	root_back.button_index = JOY_BUTTON_B
	root_back.pressed = true
	assert_true(not shell.handle_menu_input(root_back), "root Back is returned to the director for closing")

	shell.hide_menu()
	assert_true(not shell.is_open(), "shell closes")
	assert_equal(shell.loadout_page, "overview", "closing resets nested Grace navigation")
	shell.queue_free()

	if failures.is_empty():
		print("FULL_MENU_LOADOUT_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FULL_MENU_LOADOUT_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _make_menu_data() -> Dictionary:
	var spell_slots: Array[Dictionary] = []
	for slot_index: int in range(10):
		spell_slots.append({
			"slot": slot_index,
			"is_empty": slot_index >= 3,
			"name": "Test Spell " + str(slot_index + 1),
			"element": "fire",
			"description": "Test spell slot.",
			"mana_cost": 1.0,
		})
	var item_slots: Array[Dictionary] = []
	for slot_index: int in range(4):
		item_slots.append({
			"slot": slot_index,
			"direction": ["Up", "Left", "Right", "Down"][slot_index],
			"is_empty": slot_index > 0,
			"name": "Healing Flask",
			"icon": "🧪",
			"count": 3 if slot_index == 0 else 0,
		})
	return {
		"loadout_summary": {
			"learned_count": 10,
			"active_ring_count": 3,
		},
		"equipped_spell_slots": spell_slots,
		"quick_item_slots": item_slots,
		"inventory_items": [
			{
				"id": "healing_flask",
				"name": "Healing Flask",
				"icon": "🧪",
				"count": 3,
				"description": "Restores health.",
			},
		],
		"familiar_mastery": {
			"rows": [],
			"summary": {
				"familiars_unlocked": 0,
				"familiars_available": 1,
			},
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
