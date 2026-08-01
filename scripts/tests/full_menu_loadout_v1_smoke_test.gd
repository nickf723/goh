extends Node

const FullMenuShellScript = preload(
	"res://scripts/ui/full_menu_shell_loadout_v2.gd"
)
const EquipmentCatalogScript = preload(
	"res://scripts/equipment/equipment_catalog.gd"
)
const WeaponVariantCatalogScript = preload(
	"res://scripts/weapons/weapon_variant_catalog.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var shell: FullMenuShellLoadoutV2 = FullMenuShellScript.new()
	add_child(shell)
	shell.show_menu(_make_menu_data())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(shell.is_open(), "shell opens")
	assert_equal(shell.loadout_page, "overview", "Grace begins collapsed")
	assert_equal(shell.get_current_tab_id(), "loadout", "Grace remains the first tab")
	assert_equal(FullMenuShellScript.MENU_TAB_DEFS.size(), 7, "Grace and Loadout share one top-level tab")
	assert_equal(EquipmentCatalogScript.SLOT_ORDER.size(), 7, "equipment supports weapon and six wardrobe components")
	assert_equal(WeaponVariantCatalogScript.get_class_rows().size(), 16, "weapon browser exposes sixteen classes")
	assert_equal(shell.selectable_actions.size(), 15, "collapsed Grace exposes five categories and ten spells")
	assert_true(shell.find_child("GracePreview", true, false) != null, "Grace preview is present while collapsed")
	assert_true(shell.find_child("GraceStatQuadrants", true, false) != null, "four stat quadrants are present")
	assert_true(shell.find_child("GraceSpellRibbon", true, false) != null, "spell ribbon is present")

	var debug_data: Dictionary = shell.get_navigation_debug_data()
	assert_equal(int(debug_data.get("stat_quadrants", 0)), 4, "stats are chunked into four groups")
	assert_equal(int(debug_data.get("stat_count", 0)), 16, "Grace exposes sixteen simple stats")
	assert_true(bool(debug_data.get("scroll_disabled", false)), "Grace tab disables unnecessary scrolling")
	assert_equal(
		int(debug_data.get("action_count", -1)),
		int(debug_data.get("control_count", -2)),
		"every action has a screen-space navigation control"
	)

	# Spell ribbon navigation must stay on the same visible row.
	shell.select_action(9)
	await get_tree().process_frame
	shell.select_action_direction(-1, 0)
	assert_equal(shell.selected_action_index, 8, "spell-left selects the immediately previous spell")

	# Weapon expansion keeps Grace, stats, and spell ring anchored.
	shell.activate_action(shell.selectable_actions[0] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.loadout_page, "weapon_classes", "Weapon expands inside Grace")
	assert_equal(shell.selectable_actions.size(), 31, "weapon expansion keeps categories, sixteen classes, and ten spells")
	assert_true(shell.find_child("GracePreview", true, false) != null, "Grace remains visible beside weapon classes")
	assert_true(shell.find_child("GraceStatQuadrants", true, false) != null, "stats remain visible beside weapon classes")
	assert_true(shell.find_child("GraceSpellRibbon", true, false) != null, "spell ribbon remains visible beside weapon classes")

	var sword_action: Dictionary = shell.selectable_actions[5] as Dictionary
	assert_equal(str(sword_action.get("weapon_class", "")), "sword", "first class is Sword")
	shell.activate_action(sword_action)
	await get_tree().process_frame
	assert_equal(shell.loadout_page, "weapon_variants", "weapon class opens its type menu")
	assert_equal(shell.selectable_actions.size(), 19, "Sword types keep categories and spell ribbon")
	var found_rapier: bool = false
	for action_value: Variant in shell.selectable_actions:
		if (
			action_value is Dictionary
			and str((action_value as Dictionary).get("variant_id", "")) == "rapier"
		):
			found_rapier = true
	assert_true(found_rapier, "Sword types include Rapier")

	var back_event: InputEventJoypadButton = InputEventJoypadButton.new()
	back_event.button_index = JOY_BUTTON_B
	back_event.pressed = true
	assert_true(shell.handle_menu_input(back_event), "variant page consumes controller Back")
	assert_equal(shell.loadout_page, "weapon_classes", "Back returns to weapon classes")
	assert_true(shell.handle_menu_input(back_event), "class grid consumes controller Back")
	assert_equal(shell.loadout_page, "overview", "second Back collapses Weapon")

	# Reproduce the screenshot: Torso-left must choose Headwear, not Wardrobe above.
	shell.activate_action(shell.selectable_actions[1] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.loadout_page, "wardrobe", "Wardrobe expands inside Grace")
	assert_equal(shell.selectable_actions.size(), 21, "wardrobe keeps categories, six components, and spells")
	shell.select_action(6)
	await get_tree().process_frame
	shell.select_action_direction(-1, 0)
	assert_equal(shell.selected_action_index, 5, "Torso-left selects Headwear on the same row")

	# Opening another category collapses the wardrobe expansion.
	shell.activate_action(shell.selectable_actions[2] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.loadout_page, "infusion", "opening Infusion collapses Wardrobe")
	assert_true(shell.find_child("GracePreview", true, false) != null, "Grace remains visible during Infusion")

	# The right stick activates a free menu cursor without changing controller grammar.
	var right_stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	right_stick.axis = JOY_AXIS_RIGHT_X
	right_stick.axis_value = 0.8
	assert_true(shell.handle_menu_input(right_stick), "right stick motion is consumed by the menu")
	var cursor_data: Dictionary = shell.get_navigation_debug_data()
	assert_true(bool(cursor_data.get("virtual_cursor_active", false)), "right stick activates the free-target cursor")

	# L shoulder still moves left after the gameplay Focus router fix.
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

	shell.loadout_page = FullMenuShellScript.LOADOUT_OVERVIEW
	var root_back: InputEventJoypadButton = InputEventJoypadButton.new()
	root_back.button_index = JOY_BUTTON_B
	root_back.pressed = true
	assert_true(not shell.handle_menu_input(root_back), "root Back is returned to the director for closing")

	shell.hide_menu()
	assert_true(not shell.is_open(), "shell closes")
	assert_equal(shell.loadout_page, "overview", "closing resets Grace accordion")
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
