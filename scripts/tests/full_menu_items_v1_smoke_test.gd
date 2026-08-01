extends Node

const FullMenuShellScript = preload(
	"res://scripts/ui/full_menu_shell_items_v1.gd"
)
const ItemCategoryCatalogScript = preload(
	"res://scripts/items/item_inventory_category_catalog.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var catalog_failures: Array[String] = ItemCategoryCatalogScript.validate_catalog()
	assert_true(catalog_failures.is_empty(), "item category catalog validates")

	var shell: FullMenuShellItemsV1 = FullMenuShellScript.new()
	add_child(shell)
	shell.show_menu(_make_menu_data())
	shell.select_tab(shell.get_tab_index("items"))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_equal(shell.get_current_tab_id(), "items", "Items tab opens")
	assert_equal(
		FullMenuShellScript.FIELD_KIT_TAB_DEFS.size(),
		6,
		"Relics is removed from the main tab row"
	)
	assert_true(
		not _top_tabs_contain_relics(),
		"top-level tab definitions no longer contain Relics"
	)
	assert_equal(shell.items_page, "overview", "Items begins collapsed")
	assert_equal(shell.selectable_actions.size(), 7, "overview exposes seven item subtabs")
	assert_true(
		shell.find_child("ItemsCategoryStrip", true, false) != null,
		"seven-category item strip exists"
	)
	assert_true(
		bool(shell.get_items_debug_data().get("scroll_disabled", false)),
		"Items disables global scrolling"
	)

	# Potions are the third subtab.
	shell.activate_action(shell.selectable_actions[2] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.items_page, "category", "Potions expands in the shared workspace")
	assert_equal(shell.selected_item_category, "potions", "Potions is selected")
	assert_true(
		shell.find_child("ItemsOwnedGrid", true, false) != null,
		"owned potion grid is present"
	)
	assert_true(
		_has_item_action(shell.selectable_actions, "healing_potion"),
		"Healing Potion is classified under Potions"
	)
	assert_true(
		_has_item_action(shell.selectable_actions, "swift_tonic"),
		"Swift Tonic is classified under Potions"
	)

	# Relics / Key Items are the seventh subtab.
	shell.activate_action(shell.selectable_actions[6] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.selected_item_category, "relics", "Relics opens inside Items")
	assert_true(
		shell.find_child("ItemsRelicWorkspace", true, false) != null,
		"key items and persistent records share the Relics workspace"
	)

	var back_event: InputEventJoypadButton = InputEventJoypadButton.new()
	back_event.button_index = JOY_BUTTON_B
	back_event.pressed = true
	assert_true(shell.handle_menu_input(back_event), "Items category consumes Back")
	assert_equal(shell.items_page, "overview", "Back collapses to Items overview")

	shell.hide_menu()
	shell.queue_free()
	finish_tests()


func _make_menu_data() -> Dictionary:
	return {
		"inventory_items": [
			{
				"id": "oil_flask",
				"name": "Oil Flask",
				"description": "A combustible alchemical material.",
				"icon": "◉",
				"count": 2,
				"effect": "oil",
				"element": "fire",
				"tags": ["material", "reagent"],
			},
			{
				"id": "healing_potion",
				"name": "Healing Potion",
				"description": "Restores health.",
				"icon": "⚗",
				"count": 3,
				"effect": "heal",
				"element": "life",
				"tags": ["potion", "heal"],
			},
			{
				"id": "swift_tonic",
				"name": "Swift Tonic",
				"description": "Temporarily improves movement.",
				"icon": "⚗",
				"count": 1,
				"effect": "buff",
				"element": "air",
				"tags": ["tonic", "movement"],
			},
			{
				"id": "noise_maker",
				"name": "Noise Maker",
				"description": "A prototype deployable distraction.",
				"icon": "♫",
				"count": 1,
				"effect": "noise",
				"element": "sound",
				"tags": ["deployable_object"],
			},
			{
				"id": "field_ration",
				"name": "Field Ration",
				"description": "A simple prepared meal.",
				"icon": "♨",
				"count": 2,
				"inventory_category": "food",
				"tags": ["food"],
			},
			{
				"id": "amber_gem",
				"name": "Amber Gem",
				"description": "A valuable time-tinted stone.",
				"icon": "◆",
				"count": 4,
				"inventory_category": "valuables",
				"tags": ["gem", "valuable"],
			},
		],
		"key_items": [
			{
				"id": "church_trial_seal",
				"name": "Church Trial Seal",
				"description": "Proof that Grace passed the elemental trial.",
			},
		],
		"loadout_summary": {},
		"learned_spell_sections": [],
		"equipped_spell_slots": [],
		"spellcasting_mastery": {"rows": [], "summary": {}},
		"familiar_mastery": {"rows": [], "summary": {}},
	}


func _top_tabs_contain_relics() -> bool:
	for tab: Dictionary in FullMenuShellScript.FIELD_KIT_TAB_DEFS:
		if str(tab.get("id", "")) == "relics":
			return true
	return false


func _has_item_action(actions: Array, item_id: String) -> bool:
	for value: Variant in actions:
		if not value is Dictionary:
			continue
		var action: Dictionary = value as Dictionary
		if (
			str(action.get("kind", "")) == "select_inventory_record"
			and str(action.get("item_id", "")) == item_id
		):
			return true
	return false


func finish_tests() -> void:
	if failures.is_empty():
		print("FULL_MENU_ITEMS_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FULL_MENU_ITEMS_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label
			+ " (expected "
			+ str(expected)
			+ ", got "
			+ str(actual)
			+ ")"
		)
