extends Node

const FullMenuShellScript = preload(
	"res://scripts/ui/full_menu_shell_magic_v1.gd"
)
const AugmentationCatalogScript = preload(
	"res://scripts/abilities/elemental_augmentation_catalog.gd"
)

var failures: Array[String] = []
var original_augmentations: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	if GameState.has_method("get_elemental_augmentations_snapshot"):
		original_augmentations = GameState.call(
			"get_elemental_augmentations_snapshot"
		) as Dictionary

	var shell: FullMenuShellMagicV1 = FullMenuShellScript.new()
	add_child(shell)
	shell.show_menu(_make_menu_data())
	shell.select_tab(shell.get_tab_index("magic"))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_equal(shell.get_current_tab_id(), "magic", "Magic tab opens")
	assert_equal(shell.magic_page, "overview", "Magic begins collapsed")
	assert_equal(shell.selectable_actions.size(), 24, "overview exposes sixteen elements and eight traditions")
	assert_true(shell.find_child("MagicElementGrid", true, false) != null, "4x4 element grid exists")
	assert_true(shell.find_child("MagicTraditionGrid", true, false) != null, "2x4 tradition grid exists")
	var debug_data: Dictionary = shell.get_magic_debug_data()
	assert_equal(int(debug_data.get("element_count", 0)), 16, "element atlas contains sixteen elements")
	assert_equal(int(debug_data.get("tradition_count", 0)), 8, "tradition lattice contains eight traditions")
	assert_true(bool(debug_data.get("scroll_disabled", false)), "Magic disables vertical scrolling")
	assert_true(bool(debug_data.get("atlas_present", false)), "Magic atlas remains visible")
	assert_true(bool(debug_data.get("expansion_present", false)), "Magic expansion workspace exists")

	# Lightning occupies the third position of the Primal row: index 6.
	shell.activate_action(shell.selectable_actions[6] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "element", "Lightning expands into its learned spells")
	assert_equal(shell.selected_magic_element, "lightning", "Lightning is the selected element")
	assert_equal(shell.selectable_actions.size(), 26, "Lightning adds one spell and one augmentation tile")
	assert_true(shell.find_child("MagicElementGrid", true, false) != null, "element atlas persists while Lightning is open")

	var lightning_spell_action: Dictionary = shell.selectable_actions[24] as Dictionary
	assert_equal(str(lightning_spell_action.get("spell_id", "")), "lightning_spark", "Lightning spell is exposed")
	shell.activate_action(lightning_spell_action)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "spell", "spell opens a deeper craft view")
	assert_equal(shell.selected_magic_spell_id, "lightning_spark", "spell identity remains stable")
	assert_true(_has_action_kind(shell.selectable_actions, "inspect_spell_property"), "spell detail exposes properties")
	assert_true(_has_action_kind(shell.selectable_actions, "inspect_spell_upgrade"), "spell detail exposes upgrade branches")
	assert_true(_has_action_kind(shell.selectable_actions, "open_element_augmentation"), "spell detail links its element augmentation")
	assert_true(bool(shell.get_magic_debug_data().get("scroll_disabled", false)), "spell detail remains scroll-free")

	var back_event: InputEventJoypadButton = InputEventJoypadButton.new()
	back_event.button_index = JOY_BUTTON_B
	back_event.pressed = true
	assert_true(shell.handle_menu_input(back_event), "spell detail consumes Back")
	assert_equal(shell.magic_page, "element", "Back returns to Lightning spells")

	# The final element-list action is Elemental Augmentation.
	var augmentation_action: Dictionary = shell.selectable_actions.back() as Dictionary
	assert_equal(str(augmentation_action.get("kind", "")), "open_element_augmentation", "element page exposes augmentation")
	shell.activate_action(augmentation_action)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "augmentation", "augmentation unfolds beside the atlas")
	assert_equal(shell.selectable_actions.size(), 27, "Lightning augmentation offers Pure plus two directed recipes")
	assert_true(
		AugmentationCatalogScript.is_valid_pair("lightning", "fire"),
		"Lightning → Fire is an authored recipe"
	)
	assert_true(
		not AugmentationCatalogScript.is_valid_pair("fire", "lightning"),
		"Lightning → Fire does not imply Fire → Lightning"
	)
	assert_true(
		AugmentationCatalogScript.is_valid_pair("sound", "lightning"),
		"Sound → Lightning supports electromagnetic resonance"
	)
	assert_true(
		AugmentationCatalogScript.is_valid_pair("ice", "fire"),
		"Ice → Fire supports Burning Ice"
	)

	# Soul is index 11 and contains Summon Familiar.
	shell.activate_action(shell.selectable_actions[11] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "element", "Soul replaces the open augmentation")
	assert_equal(shell.selected_magic_element, "soul", "Soul is selected")
	var familiar_action: Dictionary = shell.selectable_actions[24] as Dictionary
	assert_equal(str(familiar_action.get("spell_id", "")), "spectral_familiar", "Soul files the familiar under a spell")
	shell.activate_action(familiar_action)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "spell", "Summon Familiar opens spell detail")
	assert_true(_has_action_kind(shell.selectable_actions, "select_familiar_species"), "familiar species selector is nested in the spell")
	assert_true(_has_action_kind(shell.selectable_actions, "cycle_familiar_role"), "familiar role is nested in the spell")
	assert_true(_has_action_kind(shell.selectable_actions, "cycle_familiar_temperament"), "familiar temperament is nested in the spell")
	assert_true(_has_action_kind(shell.selectable_actions, "cycle_familiar_command"), "familiar command is nested in the spell")
	assert_true(_has_action_kind(shell.selectable_actions, "toggle_familiar_technique"), "familiar techniques are nested in the spell")

	# Sorcery begins at action 16 after the sixteen elements.
	shell.activate_action(shell.selectable_actions[16] as Dictionary)
	await get_tree().process_frame
	assert_equal(shell.magic_page, "tradition", "tradition unfolds in the shared workspace")
	assert_equal(shell.selected_magic_tradition_id, "sorcery", "Sorcery is selected")
	assert_equal(shell.selectable_actions.size(), 24, "tradition detail keeps only atlas navigation actions")
	assert_true(shell.find_child("MagicElementGrid", true, false) != null, "elements remain alongside traditions")
	assert_true(bool(shell.get_magic_debug_data().get("scroll_disabled", false)), "tradition detail remains scroll-free")

	shell.hide_menu()
	shell.queue_free()
	_restore_augmentations()

	if failures.is_empty():
		print("FULL_MENU_MAGIC_V1_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FULL_MENU_MAGIC_V1_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _make_menu_data() -> Dictionary:
	var sections: Array[Dictionary] = []
	for element_id: String in FullMenuShellScript.ELEMENT_ORDER:
		var spells: Array[Dictionary] = []
		if element_id == "lightning":
			spells.append(_spell_row(
				"lightning_spark",
				"Lightning Spark",
				"lightning",
				["damage", "status", "combo_reactor"]
			))
		elif element_id == "soul":
			spells.append(_spell_row(
				"spectral_familiar",
				"Summon Familiar",
				"soul",
				["summon", "companion", "combat", "puzzle"]
			))
		sections.append({
			"element": element_id,
			"title": element_id.capitalize(),
			"spells": spells,
		})
	var mastery_rows: Array[Dictionary] = []
	for tradition_id: String in [
		"sorcery", "wizardry", "druidry", "warlock",
		"theurgy", "bardic", "artifice", "ritualism",
	]:
		mastery_rows.append({
			"id": tradition_id,
			"display_name": tradition_id.capitalize(),
			"icon": "✦",
			"relationship": "Test relationship for " + tradition_id + ".",
			"rank": 1 if tradition_id in ["sorcery", "wizardry"] else 0,
			"rank_max": 4,
			"current_stage_name": "Initiation" if tradition_id in ["sorcery", "wizardry"] else "Uninitiated",
			"stage_rows": [
				{"id": "initiation", "name": "Initiation", "unlocked": tradition_id in ["sorcery", "wizardry"]},
				{"id": "practice", "name": "Practice", "unlocked": false},
				{"id": "trial", "name": "Trial", "unlocked": false},
				{"id": "mastery", "name": "Mastery", "unlocked": false},
			],
			"compatible_spell_names": ["Lightning Spark"],
			"capstone": {
				"display_name": tradition_id.capitalize() + " Capstone",
				"description": "Reserved mastery mechanic.",
			},
		})
	return {
		"loadout_summary": {
			"learned_count": 2,
			"active_ring_count": 2,
		},
		"learned_spell_sections": sections,
		"equipped_spell_slots": [],
		"spellcasting_mastery": {
			"rows": mastery_rows,
			"summary": {
				"initiated_count": 2,
				"tradition_count": 8,
				"mastered_count": 0,
			},
		},
		"familiar_mastery": {
			"equipped_species_id": "gremlin",
			"equipped_name": "Gremlin",
			"summary": {
				"familiars_unlocked": 1,
				"familiars_available": 1,
			},
			"rows": [
				{
					"species_id": "gremlin",
					"display_name": "Gremlin",
					"icon": "◇",
					"summary": "A quick creature familiar.",
					"unlocked": true,
					"equipped": true,
					"loadout": {
						"role": "skirmisher",
						"temperament": "balanced",
						"command": "assist",
						"technique_ids": ["bite"],
					},
					"techniques": [
						{
							"id": "bite",
							"label": "Bite",
							"description": "A quick familiar attack.",
							"unlocked": true,
							"equipped": true,
						},
					],
				},
			],
		},
	}


func _spell_row(
	spell_id: String,
	name: String,
	element: String,
	roles: Array[String]
) -> Dictionary:
	return {
		"spell_id": spell_id,
		"learned_index": 0 if element == "lightning" else 1,
		"name": name,
		"description": "Test spell description.",
		"element": element,
		"category": "Summon" if spell_id == "spectral_familiar" else "Projectile",
		"mana_cost": 2,
		"stamina_cost": 0,
		"focus_cost": 0,
		"roles": roles,
		"targeting": "self" if spell_id == "spectral_familiar" else "aimed",
		"delivery": "summon" if spell_id == "spectral_familiar" else "projectile",
		"combo_tags": [element, "test"],
		"status_tags": [],
		"scaling_stats": ["arcana", element],
		"scaling_note": "Prototype scaling.",
		"is_equipped": true,
		"equipped_slot": 0,
	}


func _has_action_kind(actions: Array, kind: String) -> bool:
	for action_value: Variant in actions:
		if (
			action_value is Dictionary
			and str((action_value as Dictionary).get("kind", "")) == kind
		):
			return true
	return false


func _restore_augmentations() -> void:
	if not GameState.has_method("set_elemental_augmentation"):
		return
	for element_id: String in FullMenuShellScript.ELEMENT_ORDER:
		GameState.call("set_elemental_augmentation", element_id, "", true)
	for source_value: Variant in original_augmentations.keys():
		GameState.call(
			"set_elemental_augmentation",
			str(source_value),
			str(original_augmentations[source_value]),
			true
		)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
