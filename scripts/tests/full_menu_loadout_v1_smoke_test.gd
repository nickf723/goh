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
	assert_equal(shell.loadout_page, "overview", "Loadout begins at overview")
	assert_equal(shell.get_current_tab_id(), "loadout", "Loadout remains the first tab")
	assert_equal(shell.selectable_actions.size(), 6, "overview exposes six focused categories")
	assert_true(
		str(shell.content_title_label.text).contains("Loadout"),
		"overview owns the page title"
	)
	assert_equal(
		str((shell.selectable_actions[0] as Dictionary).get("page", "")),
		"equipment",
		"first category opens Equipment"
	)

	shell.activate_action(shell.selectable_actions[0] as Dictionary)
	assert_equal(shell.loadout_page, "equipment", "Equipment opens as a nested Loadout page")
	assert_true(
		str(shell.content_title_label.text).contains("Equipment"),
		"Equipment page receives a breadcrumb title"
	)
	assert_equal(shell.selectable_actions.size(), 4, "Equipment page exposes four slots")

	var cancel_event: InputEventAction = InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	assert_true(
		shell.handle_menu_input(cancel_event),
		"nested Loadout page consumes Back"
	)
	assert_equal(shell.loadout_page, "overview", "Back returns to Loadout overview")
	assert_equal(shell.selected_action_index, 0, "Back restores the originating category")

	shell.activate_action({"kind": "open_loadout_page", "page": "special"})
	assert_equal(shell.loadout_page, "special", "Divine Special page opens")
	assert_true(
		str(shell.content_title_label.text).contains("Divine Special"),
		"Divine Special page receives a breadcrumb title"
	)

	shell.hide_menu()
	assert_true(not shell.is_open(), "shell closes")
	assert_equal(shell.loadout_page, "overview", "closing resets nested Loadout navigation")
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
			"is_empty": slot_index >= 2,
			"name": "Test Spell " + str(slot_index + 1),
			"element": "fire",
			"description": "Test spell slot.",
			"mana_cost": 1.0,
		})
	var item_slots: Array[Dictionary] = []
	var directions: Array[String] = ["Up", "Left", "Right", "Down"]
	for slot_index: int in range(4):
		item_slots.append({
			"slot": slot_index,
			"direction": directions[slot_index],
			"is_empty": slot_index > 0,
			"name": "Healing Flask",
			"icon": "🧪",
			"count": 3 if slot_index == 0 else 0,
		})
	return {
		"loadout_summary": {
			"learned_count": 10,
			"active_ring_count": 2,
		},
		"equipped_spell_slots": spell_slots,
		"quick_item_slots": item_slots,
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
