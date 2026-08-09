extends Node

const PlantSpellDetailShellScript = preload(
	"res://scripts/ui/full_menu_shell_plant_spell_detail.gd"
)
const PreparedPlantLoadoutScript = preload(
	"res://scripts/life/prepared_plant_loadout.gd"
)

const TEST_SAVE_PATH: String = "user://goh_plant_spell_detail_smoke.json"

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_delete_test_save()
	var store: PreparedPlantLoadout = (
		PreparedPlantLoadoutScript.get_or_create(get_tree(), TEST_SAVE_PATH)
		as PreparedPlantLoadout
	)
	_expect(store != null, "prepared plant store is available")
	if store == null:
		_finish()
		return
	store.prepare_plant("broadleaf_sprout", false)
	store.set_parameter("size", "standard", false)
	store.set_parameter("persistence", "standard", false)
	store.set_parameter("emergence", "balanced", true)

	var shell: FullMenuShellPlantSpellDetail = PlantSpellDetailShellScript.new()
	add_child(shell)
	shell.show_menu(_make_menu_data())
	shell.select_tab(shell.get_tab_index("magic"))
	await get_tree().process_frame
	await get_tree().process_frame

	var life_action: Dictionary = _find_action(
		shell.selectable_actions,
		"toggle_magic_element",
		"element",
		"life"
	)
	_expect(not life_action.is_empty(), "Magic atlas exposes Life")
	if life_action.is_empty():
		shell.queue_free()
		_finish()
		return
	shell.activate_action(life_action)
	await get_tree().process_frame

	var plant_action: Dictionary = _find_action(
		shell.selectable_actions,
		"open_magic_spell",
		"spell_id",
		"sprout"
	)
	_expect(not plant_action.is_empty(), "Life exposes Plant Summon spell detail")
	if plant_action.is_empty():
		shell.queue_free()
		_finish()
		return
	shell.activate_action(plant_action)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(shell.magic_page == "spell", "Plant Summon opens the spell craft view")
	_expect(shell.selected_magic_spell_id == "sprout", "Plant Summon keeps the stable internal spell id")
	_expect(shell.find_child("PlantSummonPreparedSummary", true, false) != null, "prepared blueprint summary renders inside spell detail")
	var parameter_grid: Node = shell.find_child("PlantSummonParameterGrid", true, false)
	_expect(parameter_grid is GridContainer, "prepared parameter controls render inside spell detail")
	_expect(_count_action_kind(shell.selectable_actions, "cycle_plant_parameter") == 3, "Broadleaf exposes three pre-combat parameter controls")

	var before_size: String = str(store.get_prepared_parameters().get("size", ""))
	var size_action: Dictionary = _find_action(
		shell.selectable_actions,
		"cycle_plant_parameter",
		"parameter_id",
		"size"
	)
	_expect(not size_action.is_empty(), "Growth Size is actionable from Plant Summon detail")
	if not size_action.is_empty():
		shell.activate_action(size_action)
		await get_tree().process_frame
		var after_size: String = str(store.get_prepared_parameters().get("size", ""))
		_expect(after_size != before_size, "selecting Growth Size changes the prepared blueprint")
		_expect(shell.magic_page == "spell", "changing a plant parameter keeps the Plant Summon detail open")
		_expect(shell.selected_magic_spell_id == "sprout", "changing a plant parameter does not lose spell selection")

	shell.hide_menu()
	shell.queue_free()
	await get_tree().process_frame
	_delete_test_save()
	_finish()


func _make_menu_data() -> Dictionary:
	var sections: Array[Dictionary] = []
	for element_id: String in PlantSpellDetailShellScript.ELEMENT_ORDER:
		var spells: Array[Dictionary] = []
		if element_id == "life":
			spells.append({
				"spell_id": "sprout",
				"learned_index": 0,
				"name": "Plant Summon",
				"description": "Grow the prepared plant blueprint.",
				"element": "life",
				"category": "Utility",
				"mana_cost": 2,
				"stamina_cost": 0,
				"focus_cost": 0,
				"roles": ["summon", "plant_summon", "utility"],
				"targeting_style": "ground_placement",
				"delivery_type": "prepared_plant_summon",
				"scaling_stats": ["life", "arcana", "skill"],
				"combo_tags": ["life", "plant", "summon"],
			})
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
			"relationship": "Test tradition.",
			"rank": 0,
			"rank_max": 4,
			"current_stage_name": "Uninitiated",
			"stage_rows": [],
			"compatible_spell_names": [],
			"capstone": {},
		})

	return {
		"loadout_summary": {"learned_count": 1, "active_ring_count": 1},
		"learned_spell_sections": sections,
		"equipped_spell_slots": [],
		"spellcasting_mastery": {
			"rows": mastery_rows,
			"summary": {
				"initiated_count": 0,
				"tradition_count": 8,
				"mastered_count": 0,
			},
		},
		"familiar_mastery": {"rows": [], "summary": {}},
	}


func _find_action(
	actions: Array,
	kind: String,
	field: String,
	value: String
) -> Dictionary:
	for action_value: Variant in actions:
		if not action_value is Dictionary:
			continue
		var action: Dictionary = action_value as Dictionary
		if str(action.get("kind", "")) != kind:
			continue
		if str(action.get(field, "")) == value:
			return action
	return {}


func _count_action_kind(actions: Array, kind: String) -> int:
	var count: int = 0
	for action_value: Variant in actions:
		if action_value is Dictionary and str((action_value as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PLANT_SPELL_DETAIL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PLANT_SPELL_DETAIL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
