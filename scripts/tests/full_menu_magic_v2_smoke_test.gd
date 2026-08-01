extends Node

const FullMenuShellScript = preload(
	"res://scripts/ui/full_menu_shell_magic_v2.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var shell: FullMenuShellMagicV2 = FullMenuShellScript.new()
	add_child(shell)
	shell.show_menu(_make_menu_data())
	shell.select_tab(shell.get_tab_index("magic"))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_equal(shell.get_current_tab_id(), "magic", "Magic tab opens")
	assert_equal(shell.selectable_actions.size(), 24, "overview exposes sixteen elements and eight traditions")

	# A right-stick cursor yields cleanly when directional controls take over.
	var right_stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
	right_stick.axis = JOY_AXIS_RIGHT_X
	right_stick.axis_value = 0.85
	assert_true(shell.handle_menu_input(right_stick), "right stick activates menu cursor")
	assert_true(shell.virtual_cursor_active, "virtual cursor becomes active")
	var dpad_right: InputEventJoypadButton = InputEventJoypadButton.new()
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad_right.pressed = true
	assert_true(shell.handle_menu_input(dpad_right), "D-pad movement is consumed")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(not shell.virtual_cursor_active, "D-pad takes ownership from the hovering cursor")
	assert_equal(shell.selected_action_index, 1, "D-pad movement survives the cursor handoff")

	# Space is index fourteen in the fixed atlas.
	shell.activate_action(shell.selectable_actions[14] as Dictionary)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_equal(shell.magic_page, "element", "Space expands into its school workspace")
	assert_equal(shell.selected_magic_element, "space", "Space is selected")

	var spell_grid: GridContainer = shell.find_child(
		"MagicElementSpellGrid",
		true,
		false
	) as GridContainer
	assert_true(spell_grid != null, "element spell grid exists")
	if spell_grid != null:
		assert_equal(spell_grid.columns, 4, "spell grid uses four columns")
		assert_equal(spell_grid.get_child_count(), 8, "spell grid always exposes eight sockets")

	var augmentation_grid: GridContainer = shell.find_child(
		"MagicAugmentationStrip",
		true,
		false
	) as GridContainer
	assert_true(augmentation_grid != null, "augmentation strip exists")
	if augmentation_grid != null:
		assert_equal(augmentation_grid.columns, 3, "augmentation strip uses three columns")
		assert_equal(augmentation_grid.get_child_count(), 3, "Pure plus two authored augmentations are visible")

	var debug_data: Dictionary = shell.get_magic_debug_data()
	assert_equal(int(debug_data.get("spell_slots_per_element", 0)), 8, "Magic reserves eight spell slots per element")
	assert_equal(int(debug_data.get("augmentation_slot_count", 0)), 3, "Magic reserves three augmentation choices")
	assert_true(bool(debug_data.get("augmentation_strip_present", false)), "augmentation strip is reported by debug data")
	assert_true(bool(debug_data.get("scroll_disabled", false)), "Magic remains completely scroll-free")

	assert_equal(shell.selectable_actions.size(), 28, "one learned spell plus three augmentation choices extend the atlas")
	assert_equal(str((shell.selectable_actions[24] as Dictionary).get("spell_id", "")), "space_blink", "learned spell occupies the first spell action")
	assert_equal(str((shell.selectable_actions[25] as Dictionary).get("kind", "")), "set_elemental_augmentation", "Pure choice is a direct augmentation action")
	assert_equal(str((shell.selectable_actions[25] as Dictionary).get("target", "missing")), "", "Pure choice clears augmentation")
	assert_true(not _has_action_kind(shell.selectable_actions, "open_element_augmentation"), "augmentation no longer masquerades as a spell tile")

	shell.hide_menu()
	shell.queue_free()

	if failures.is_empty():
		print("FULL_MENU_MAGIC_V2_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FULL_MENU_MAGIC_V2_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _make_menu_data() -> Dictionary:
	var sections: Array[Dictionary] = []
	for element_id: String in FullMenuShellScript.ELEMENT_ORDER:
		var spells: Array[Dictionary] = []
		if element_id == "space":
			spells.append({
				"spell_id": "space_blink",
				"name": "Space Blink",
				"description": "Fold a short distance through space.",
				"element": "space",
				"category": "Utility",
				"mana_cost": 1,
				"stamina_cost": 0,
				"focus_cost": 0,
				"roles": ["movement", "utility"],
				"targeting": "directional",
				"delivery": "instant",
				"combo_tags": ["movement"],
				"status_tags": [],
				"scaling_stats": ["focus", "space"],
				"learned_index": 0,
				"slot": 1,
				"is_equipped": true,
				"equipped_slot": 1,
			})
		sections.append({
			"element": element_id,
			"title": element_id.capitalize(),
			"spells": spells,
		})

	return {
		"loadout_summary": {
			"learned_count": 1,
			"active_ring_count": 1,
		},
		"learned_spell_sections": sections,
		"equipped_spell_slots": [],
		"spellcasting_mastery": {
			"rows": [],
			"summary": {
				"initiated_count": 2,
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


func _has_action_kind(actions: Array, kind: String) -> bool:
	for value: Variant in actions:
		if value is Dictionary and str((value as Dictionary).get("kind", "")) == kind:
			return true
	return false


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
