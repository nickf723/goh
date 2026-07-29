extends "res://scripts/ui/full_menu_director_core.gd"

const FullMenuMasteryShellScript = preload(
	"res://scripts/ui/full_menu_shell_mastery.gd"
)
const SpellcastingMasteryServiceScript = preload(
	"res://scripts/progression/spellcasting_mastery_service.gd"
)
const SpellcastingTraditionCatalogScript = preload(
	"res://scripts/progression/spellcasting_tradition_catalog.gd"
)
const SpellcastingTraditionResolverScript = preload(
	"res://scripts/abilities/spellcasting_tradition_resolver.gd"
)


func ensure_full_menu_shell() -> void:
	if full_menu_shell != null and is_instance_valid(full_menu_shell):
		return
	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return
	var existing_shell: Node = game_ui.get_node_or_null("FullMenuShell")
	if existing_shell is Control and existing_shell.has_method("show_menu"):
		full_menu_shell = existing_shell as Control
		return
	full_menu_shell = FullMenuMasteryShellScript.new()
	full_menu_shell.name = "FullMenuShell"
	full_menu_shell.process_mode = Node.PROCESS_MODE_ALWAYS
	game_ui.add_child(full_menu_shell)


func build_menu_data() -> Dictionary:
	var data: Dictionary = super.build_menu_data()
	data["spellcasting_mastery"] = get_spellcasting_mastery_data()
	return data


func make_spell_row(
	ability: AbilityDefinition,
	slot_index: int,
	current_index: int,
	learned_index: int = -1
) -> Dictionary:
	var row: Dictionary = super.make_spell_row(
		ability,
		slot_index,
		current_index,
		learned_index
	)
	if ability == null:
		row["compatible_traditions"] = []
		return row
	row["compatible_traditions"] = SpellcastingTraditionResolverScript.resolve(ability)
	return row


func get_spellcasting_mastery_data() -> Dictionary:
	SpellcastingMasteryServiceScript.ensure_story_baseline()
	var compatible_spell_names: Dictionary = {}
	for tradition_id: String in SpellcastingTraditionCatalogScript.TRADITION_IDS:
		compatible_spell_names[tradition_id] = []

	var ability_caster: Node = get_ability_caster()
	var loadout: AbilityLoadout = get_ability_loadout(ability_caster)
	if loadout != null:
		for ability_variant: Variant in get_learned_abilities(loadout):
			if not ability_variant is AbilityDefinition:
				continue
			var ability: AbilityDefinition = ability_variant as AbilityDefinition
			for tradition_id: String in SpellcastingTraditionResolverScript.resolve(ability):
				var names: Array[String] = _mastery_copy_string_array(
					compatible_spell_names.get(tradition_id, [])
				)
				if not names.has(ability.display_name):
					names.append(ability.display_name)
				compatible_spell_names[tradition_id] = names

	var rows: Array[Dictionary] = SpellcastingMasteryServiceScript.get_progress_rows()
	for row: Dictionary in rows:
		var tradition_id: String = str(row.get("id", ""))
		var names: Array[String] = _mastery_copy_string_array(
			compatible_spell_names.get(tradition_id, [])
		)
		row["compatible_spell_names"] = names
		row["compatible_spell_count"] = names.size()

	return {
		"rows": rows,
		"summary": SpellcastingMasteryServiceScript.get_summary(),
		"persistence_scope": "save_slot",
	}


func _mastery_copy_string_array(raw_values: Variant) -> Array[String]:
	var values: Array[String] = []
	if not raw_values is Array:
		return values
	for raw_value: Variant in raw_values as Array:
		var value: String = str(raw_value)
		if value != "":
			values.append(value)
	return values
